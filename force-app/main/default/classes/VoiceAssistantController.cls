public without sharing class VoiceAssistantController {

    private static Double parseDouble(Object val) {
        if (val == null) return 0.0;
        try {
            return Double.valueOf(val);
        } catch (Exception e) {
            return 0.0;
        }
    }

    public class VoiceResponse {
        @AuraEnabled public String intent;                          // 'log_timesheet', 'check_in', 'apply_leave', etc.
        @AuraEnabled public Map<String, Object> data;               // Single-entry extracted fields (backward compat)
        @AuraEnabled public List<Map<String, Object>> entries;      // Multi-entry timesheet array
        @AuraEnabled public String message;                         // Response message to user
        @AuraEnabled public Boolean isFallback;                     // True if local logic was used (no AI)
        
        // Leave fields (AuraEnabled for LWC skip-steps)
        @AuraEnabled public String leaveType;
        @AuraEnabled public String startDate;
        @AuraEnabled public String endDate;
        @AuraEnabled public String reason;
    }

    // VoiceResponse is already defined above

    // ─── MAIN ENTRY POINT ─────────────────────────────────────────────────
    @AuraEnabled
    public static String processVoiceCommandJson(String text, String userId) {
        try {
            VoiceResponse response = processVoiceCommand(text, userId);
            return JSON.serialize(response);
        } catch (Exception e) {
            return '{"intent":"unknown","message":"Error: ' + e.getMessage() + '"}';
        }
    }

    @AuraEnabled
    public static VoiceResponse processVoiceCommand(String text, String userId) {
        VoiceResponse response = new VoiceResponse();
        response.data = new Map<String, Object>();
        response.isFallback = false;

        try {
            // EMERGENCY KEYWORD PRE-EMPTION (If text is very clear, don't even wait for AI)
            String lower = text.trim().toLowerCase();
            if (lower.contains('update') && lower.contains('leave')) {
                return processLocally(text, userId);
            }
            if (lower.contains('cancel') && lower.contains('leave')) {
                return processLocally(text, userId);
            }
            if (lower.contains('apply') && lower.contains('leave')) {
                return processLocally(text, userId);
            }
            if (lower.contains('leave') && lower.contains('balance')) {
                return processLocally(text, userId);
            }
            if (lower.contains('attendance') && (lower.contains('details') || lower.contains('summary'))) {
                return processLocally(text, userId);
            }
            if (lower.contains('check') && (lower.contains('in') || lower.contains('out'))) {
                return processLocally(text, userId);
            }

            // 1. Fetch context data (projects + last timesheet) for AI prompt
            String contextStr = buildContext(userId);
            
            // DIAGNOSTIC LOG: See how context is built
            try {
                Service__c controllerLog = new Service__c();
                controllerLog.Name = 'CONTROLLER DEBUG ' + userId.left(5);
                controllerLog.Email_Body__c = 'INPUT TEXT: ' + text + '\nCONTEXT: ' + contextStr;
                controllerLog.Whatsapp__c = true;
                insert controllerLog;
            } catch(Exception logEx) {}

            // 2. Call Sarvam AI
            String aiJson = callSarvamAI(text, contextStr, userId);

            if (String.isNotBlank(aiJson)) {
                // LOG RAW AI RESPONSE FOR DEBUGGING (only for WhatsApp or if intent is unknown)
                if (aiJson.contains('"intent":"unknown"') || !aiJson.trim().startsWith('{')) {
                    try {
                        Service__c aiLog = new Service__c();
                        aiLog.Name = 'AI DEBUG ' + Datetime.now().format();
                        aiLog.Email_Body__c = 'TEXT: ' + text + '\nRESPONSE: ' + aiJson;
                        aiLog.Whatsapp__c = true;
                        insert aiLog;
                    } catch(Exception eLog) {}
                }
                return parseAIResponse(aiJson, userId);
            }

            // 3. Fallback if AI call failed or returned nothing
            response.isFallback = true;
            return processLocally(text, userId);

        } catch (Exception e) {
            System.debug('VoiceAssistantController error: ' + e.getMessage());
            // Graceful fallback
            VoiceResponse fallback = processLocally(text, userId);
            fallback.isFallback = true;
            return fallback;
        }
    }

    @AuraEnabled
    public static String executeVoiceActionFromJson(String jsonStr, String userId) {
        if (String.isBlank(jsonStr)) return 'No input data received.';
        try {
            // Use untyped deserialization to be flexible with AI-generated JSON
            Map<String, Object> parsed = (Map<String, Object>) JSON.deserializeUntyped(jsonStr);
            VoiceResponse res = new VoiceResponse();
            res.intent = (String) parsed.get('intent');
            res.message = (String) parsed.get('message');
            res.data = new Map<String, Object>();
            res.entries = new List<Map<String, Object>>();

            // ✅ FIX: Extract leave fields from top-level JSON (previously missing — caused null leave data)
            res.leaveType = (String) parsed.get('leaveType');
            res.startDate  = (String) parsed.get('startDate');
            res.endDate    = (String) parsed.get('endDate');
            res.reason     = (String) parsed.get('reason');

            // Map data
            Object dataObj = parsed.get('data');
            if (dataObj instanceof Map<String, Object>) {
                Map<String, Object> dataMap = (Map<String, Object>) dataObj;
                for (String k : dataMap.keySet()) res.data.put(k, dataMap.get(k));
            }

            // Map entries
            Object entriesObj = parsed.get('entries');
            if (entriesObj instanceof List<Object>) {
                List<Object> entriesList = (List<Object>) entriesObj;
                for (Object item : entriesList) {
                    if (item instanceof Map<String, Object>) res.entries.add((Map<String, Object>)item);
                }
            }

            // Sync entries for backward compat if empty
            if (res.entries.isEmpty() && res.data.containsKey('projectId')) {
                res.entries.add(new Map<String, Object>(res.data));
            }

            return executeVoiceAction(res, userId);
        } catch (Exception e) {
            System.debug('Deserialization error: ' + e.getMessage());
            return 'Deserialization error: ' + e.getMessage();
        }
    }

    @AuraEnabled
    public static String executeVoiceAction(VoiceResponse res, String userId) {
        if (res == null || String.isBlank(res.intent)) return 'No intent detected.';
        
        // Convert VoiceResponse to Map for Service Router
        Map<String, Object> data = new Map<String, Object>();
        data.put('intent', res.intent);
        if (String.isNotBlank(res.message)) data.put('message', res.message);
        if (String.isNotBlank(res.leaveType)) data.put('leaveType', res.leaveType);
        if (String.isNotBlank(res.startDate)) data.put('startDate', res.startDate);
        if (String.isNotBlank(res.endDate)) data.put('endDate', res.endDate);
        if (String.isNotBlank(res.reason)) data.put('reason', res.reason);
        if (res.data != null) data.putAll(res.data);
        if (res.entries != null) data.put('entries', res.entries);

        return HRMS_ActionService.executeIntent(data, userId);
    }

    @AuraEnabled
    public static String checkService() {
        return 'Connectivity OK';
    }

    // ─── SPEECH TO TEXT ──────────────────────────────────────────────────
    @AuraEnabled
    public static String transcribeAudio(String p1, String p2) {
        String base64Audio = p1;
        String audioMimeType = p2;
        if (String.isBlank(base64Audio)) return null;
        Blob audioBlob = EncodingUtil.base64Decode(base64Audio);
        return transcribeBlob(audioBlob, audioMimeType);
    }

    public static String transcribeBlob(Blob audioBlob, String audioMimeType) {
        String apiKey = Label.SarvamAI_API_Key;
        if (audioBlob == null || String.isBlank(apiKey)) return null;
        
        String mimeType = (String.isNotBlank(audioMimeType) && audioMimeType.contains(';')) ? audioMimeType.split(';')[0] : (String.isNotBlank(audioMimeType) ? audioMimeType : 'audio/wav');

        Http http = new Http();
        HttpRequest req = new HttpRequest();
        req.setEndpoint('https://api.sarvam.ai/speech-to-text');
        req.setMethod('POST');
        req.setHeader('api-subscription-key', apiKey); 
        
        String boundary = 'sfdc_boundary';
        req.setHeader('Content-Type', 'multipart/form-data; boundary=' + boundary);
        
        String bodyHeader = '--' + boundary + '\r\n' +
                           'Content-Disposition: form-data; name="model"\r\n\r\n' +
                           'saaras:v3\r\n' +
                           '--' + boundary + '\r\n' +
                           'Content-Disposition: form-data; name="file"; filename="voice.wav"\r\n' +
                           'Content-Type: ' + mimeType + '\r\n\r\n';
        
        String bodyFooter = '\r\n--' + boundary + '--';
        
        String headerHex = EncodingUtil.convertToHex(Blob.valueOf(bodyHeader));
        String audioHex = EncodingUtil.convertToHex(audioBlob);
        String footerHex = EncodingUtil.convertToHex(Blob.valueOf(bodyFooter));
        
        req.setBodyAsBlob(EncodingUtil.convertFromHex(headerHex + audioHex + footerHex));
        req.setTimeout(30000); 

        try {
            HttpResponse res = http.send(req);
            if (res.getStatusCode() == 200) {
                Map<String, Object> resBody = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                return (String) resBody.get('transcript');
            } else {
                throw new CalloutException('STT error ' + res.getStatusCode() + ': ' + res.getBody());
            }
        } catch (Exception e) {
            System.debug('Sarvam Exception: ' + e.getMessage());
            throw e;
        }
    }

    // ─── SARVAM AI CALLOUT ────────────────────────────────────────────────
    private static String callSarvamAI(String userText, String contextStr, String userId) {
        // Read API key from Custom Label (Setup > Custom Labels > SarvamAI_API_Key)
        String apiKey = Label.SarvamAI_API_Key;
        if (String.isBlank(apiKey)) return null;

        String todayStr = Date.today().format();
        // Day-of-week index: 0=Sun, 1=Mon, ..., 6=Sat
        Integer dow = Date.today().toStartOfWeek().daysBetween(Date.today());
        // Most-recent-past occurrence of each weekday (including today if it IS that day)
        // Formula: daysAgo = (currentDow - targetDow + 7) % 7
        String monDate = Date.today().addDays(-Math.mod(dow - 1 + 7, 7)).format();
        String tueDate = Date.today().addDays(-Math.mod(dow - 2 + 7, 7)).format();
        String wedDate = Date.today().addDays(-Math.mod(dow - 3 + 7, 7)).format();
        String thuDate = Date.today().addDays(-Math.mod(dow - 4 + 7, 7)).format();
        String friDate = Date.today().addDays(-Math.mod(dow - 5 + 7, 7)).format();
        String satDate = Date.today().addDays(-Math.mod(dow - 6 + 7, 7) == 0 ? 0 : -Math.mod(dow - 6 + 7, 7)).format();
        String sunDate = Date.today().addDays(-Math.mod(dow - 0 + 7, 7) == 0 ? 0 : -Math.mod(dow - 0 + 7, 7)).format();

        String[] dayNames = new String[]{'Sunday','Monday','Tuesday','Wednesday','Thursday','Friday','Saturday'};
        String todayDay = dayNames[dow];

        // Compute next-week and last-week date references (for "next week Thursday", "last week Wednesday", etc.)
        // This week's Monday: toStartOfWeek() gives Sunday, +1 = Monday
        Date thisWeekMonday = Date.today().toStartOfWeek().addDays(1);
        Date lastWeekMon = thisWeekMonday.addDays(-7);
        Date nextWeekMon = thisWeekMonday.addDays(7);

        // Most-recent weekday (Mon-Fri): if today is Sat or Sun, go back to Friday
        Date mostRecentWeekday = Date.today();
        if (dow == 6) mostRecentWeekday = Date.today().addDays(-1); // Sat → Fri
        if (dow == 0) mostRecentWeekday = Date.today().addDays(-2); // Sun → Fri

        String systemPrompt =
            'You are a high-intelligence professional HR Assistant. Extract timesheet/attendance intents from English voice commands.' +
            ' Today: ' + todayStr + ' (' + todayDay + ').' +
            ' ─── THIS WEEK: Mon=' + thisWeekMonday.format() + ', Tue=' + thisWeekMonday.addDays(1).format() + ', Wed=' + thisWeekMonday.addDays(2).format() + ', Thu=' + thisWeekMonday.addDays(3).format() + ', Fri=' + thisWeekMonday.addDays(4).format() + '.' +
            ' ─── LAST WEEK: Mon=' + lastWeekMon.format() + ', Tue=' + lastWeekMon.addDays(1).format() + ', Wed=' + lastWeekMon.addDays(2).format() + ', Thu=' + lastWeekMon.addDays(3).format() + ', Fri=' + lastWeekMon.addDays(4).format() + '.' +
            ' ─── NEXT WEEK: Mon=' + nextWeekMon.format() + ', Tue=' + nextWeekMon.addDays(1).format() + ', Wed=' + nextWeekMon.addDays(2).format() + ', Thu=' + nextWeekMon.addDays(3).format() + ', Fri=' + nextWeekMon.addDays(4).format() + '.' +
            ' ─── MOST RECENT WORKING DAY (for "today" when today is weekend): ' + mostRecentWeekday.format() + '.' +
            ' Available Context: ' + contextStr +

            '\n\n=== STRICT LANGUAGE POLICY (CRITICAL) ===' +
            '\n- Input is sometimes picked up as Tamil script. IGNORE IT.' +
            '\n- Respond ONLY in clean English.' +
            '\n- If input is not English or gibberish, return {"intent":"unknown","message":"Please speak clearly in English."}' +

            '\n\n=== 1. TASK PROFESSIONALIZATION (CRITICAL) ===' +
            '\n- REWRITE user descriptions into professional, clear English sentences.' +
            '\n- STRIP ALL introductory meta-speech like "update the", "correct my", "I have finished", "remaining hours", "spent time on".' +
            '\n- NEVER start the task with the word "Update" or "Correct" unless actually editing code.' +
            '\n- Input: "Update my Project 1 hours to 4 from bug fixing task"' +
            '\n- Good Task: "Fixed bugs for Project 1."' +

            '\n\n=== 2. DYNAMIC STATUS ===' +
            '\n- If user says "finished", "completed", "done", "fixed everything", set "status": "Completed".' +
            '\n- Default to "In Progress".' +

            '\n\n=== 3. MULTI-ENTRY TIMESHEET SPLITTING (CRITICAL) ===' +
            '\n- If user mentions multiple projects in ONE message, create SEPARATE entries in "entries" array.' +
            '\n- Example: "Feb 24 I worked 3 hours on Book Trust testing and Wadhwani 5 hrs org setup"' +
            '\n  → entries: [{projectName:"Book Trust",date:"2026-02-24",hours:3,task:"Testing"},{projectName:"Wadhwani",date:"2026-02-24",hours:5,task:"Org Setup"}]' +
            '\n- Split by "and", "also", "plus", "another" separators.' +

            '\n\n=== 4. TIMESHEET DATE RULES (WORKING DAYS ONLY) ===' +
            '\n- Timesheet can be logged for TODAY or any PAST date. NOT future dates.' +
            '\n- TODAY RULE: If today is a weekend (Sat/Sun), "today" for timesheet = the MOST RECENT WORKING DAY = ' + mostRecentWeekday.format() + '.' +
            '\n- YESTERDAY RULE: "yesterday" = the working day before most-recent-weekday.' +
            '\n- "last week Wednesday" → Use LAST WEEK dates table above: Wed = ' + lastWeekMon.addDays(2).format() + '.' +
            '\n- "next week Thursday" → Use NEXT WEEK dates: Thu = ' + nextWeekMon.addDays(3).format() + ' (NOTE: this is a FUTURE date — reject for timesheet, suggest usage for leave instead).' +
            '\n- "this week Thursday" → This week Thu = ' + thisWeekMonday.addDays(3).format() + '.' +
            '\n- Specific date like "Feb 24", "March 5" → use exact YYYY-MM-DD.' +
            '\n- DO NOT use future dates for timesheet. Return intent "unknown" with message if user mentions a future date for timesheet.' +
            '\n\n=== 4b. LEAVE DATE RULES (WORKING DAYS ONLY) ===' +
            '\n- Leave must be TODAY or FUTURE. NEVER past dates.' +
            '\n- Weekends (Sat/Sun) cannot be leave days. The backend will reject them.' +
            '\n- "Apply leave for tomorrow" → check if tomorrow is a weekday. If tomorrow is Sunday, set startDate as the NEXT Monday.' +
            '\n- "next one week" → startDate = next Monday (' + nextWeekMon.format() + '), endDate = next Friday (' + nextWeekMon.addDays(4).format() + ').' +
            '\n- "next week" (Mon-Fri) → startDate = ' + nextWeekMon.format() + ', endDate = ' + nextWeekMon.addDays(4).format() + '.' +
            '\n- "next week Thursday" → startDate = endDate = ' + nextWeekMon.addDays(3).format() + '.' +
            '\n- "last week Thursday" → PAST DATE → reject with message: Leave cannot be applied for past dates.' +
            '\n- "March 2 to 5" → startDate=2026-03-02, endDate=2026-03-05. Check: March 2 is a Monday ✓, March 5 is a Thursday ✓.' +
            '\n- "March 2 to March 7" → March 7 = Friday ✓, but March 8 = Saturday → use March 7 as endDate.' +


            '\n\n=== 5. PROJECT VALIDATION (CRITICAL) ===' +
            '\n- The Available Context contains the user\'s assigned projects (after "Projects:").' +
            '\n- If user mentions a project NOT in their assigned list, use intent "project_not_found".' +
            '\n- project_not_found: {"intent":"project_not_found","projectName":"<name said>","message":"Project <name> is not assigned to you. Your assigned projects are: [list]"}' +
            '\n- ONLY include entries[] where projectName matches one from the assigned project list.' +

            '\n\n=== 6. TIMESHEET SMART UPSERT ===' +
            '\n- If user says "update", "correct", "change hours", "I said 3 but it was 4": keep same projectName + task + date.' +
            '\n- The system auto-detects same date+project+task and UPDATES the existing entry (no duplicate is created).' +
            '\n- For updates, set the corrected hours value in entries.' +

            '\n\n=== 7b. LEAVE BALANCE & ATTENDANCE DETAILS ===' +
            '\n- If user says "leave balance", "remaining leaves", "how many leaves do I have" → use "leave_balance".' +
            '\n- If user says "my attendance", "attendance summary", "attendance details", "how many days present" → use "attendance_summary".' +
            '\n- Do not ask for dates or projects for these intents. Just return the intent and a fetching message.' +

            '\n\n=== INTENTS & SCHEMAS ===' +
            '\n- "log_timesheet": {"intent":"log_timesheet", "entries":[{"projectName","date","hours","status","task"}], "message":"..."}' +
            '\n- "apply_leave": {"intent":"apply_leave", "leaveType":"Sick/Casual/etc", "startDate":"YYYY-MM-DD", "endDate":"YYYY-MM-DD", "reason":"...", "message":"..."}' +
            '\n- "update_leave": {"intent":"update_leave", "startDate":"YYYY-MM-DD", "endDate":"YYYY-MM-DD", "newLeaveType":"Casual Leave", "newReason":"attending marriage", "message":"..."}' +
            '\n- "cancel_leave": {"intent":"cancel_leave", "startDate":"YYYY-MM-DD", "endDate":"YYYY-MM-DD", "message":"..."}' +
            '\n- "leave_balance": {"intent":"leave_balance", "message":"Fetching your leave balance..."}' +
            '\n- "attendance_summary": {"intent":"attendance_summary", "message":"Fetching your attendance details..."}' +
            '\n- "project_not_found": {"intent":"project_not_found", "projectName":"<said name>", "message":"<friendly explanation>"}' +
            '\n- "check_in": {"intent":"check_in", "message":"Checking you in..."}' +
            '\n- "check_out": {"intent":"check_out", "message":"Checking you out..."}' +
            '\n- "unknown": {"intent":"unknown", "message":"Please speak clearly in English."}' +
            '\n\n=== 7b. LEAVE UPDATE & CANCEL RULES ===' +
            '\n- UPDATE: If user says "I applied wrong leave type", "change my sick leave to casual", "update the reason" → use "update_leave".' +
            '\n- Provide "newLeaveType" if changing type (e.g., "Casual Leave"), "newReason" if changing reason, or both.' +
            '\n- CANCEL: If user says "cancel my leave", "withdraw my leave application" → use "cancel_leave".' +
            '\n- For both update and cancel: extract the date (startDate/endDate) of the leave being modified.' +
            '\n- The backend will block these actions if the leave is already Approved (user must contact HR).' +

            '\n\n=== 7. LEAVE DATE RANGE RULES (CRITICAL) ===' +
            '\n- Leave must be TODAY or FUTURE. NEVER resolve leave dates to past dates.' +
            '\n- "next one week" → startDate = tomorrow (' + Date.today().addDays(1).format() + '), endDate = today+7 (' + Date.today().addDays(7).format() + ').' +
            '\n- "next week" → startDate = next Monday, endDate = next Friday.' +
            '\n- "March 2 to 5" → startDate = 2026-03-02, endDate = 2026-03-05.' +
            '\n- "from March 2nd to March 5th" → Same as above, always extract exact YYYY-MM-DD dates.' +
            '\n- Single day: "March 4th" → startDate = endDate = 2026-03-04.' +
            '\n- "tomorrow" → startDate = endDate = ' + Date.today().addDays(1).format() + '.' +
            '\n- Reason: extract from "for a tour", "due to fever", "going to temple" etc.' +
            '\n- Use EXACT leave type names from the Available Context (from "Leave Types: [...]" in context).' +


            '\n\n=== RESPONSE FORMAT ===' +
            '\nReturn ONLY valid JSON.';

        // Build request body (OpenAI-compatible format)
        Map<String, Object> reqBody = new Map<String, Object>{
            'model' => 'sarvam-m',
            'messages' => new List<Object>{
                new Map<String, String>{'role' => 'system', 'content' => systemPrompt},
                new Map<String, String>{'role' => 'user', 'content' => userText}
            },
            'temperature' => 0.1,
            'max_tokens' => 1500  // Increased for multi-entry arrays
        };

        Http http = new Http();
        HttpRequest req = new HttpRequest();
        req.setEndpoint('https://api.sarvam.ai/v1/chat/completions');
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setHeader('Authorization', 'Bearer ' + apiKey);
        req.setBody(JSON.serialize(reqBody));
        req.setTimeout(60000); // Increased to 60 seconds for reliability

        HttpResponse res = http.send(req);

        // EXHAUSTIVE LOGGING FOR AI CALLOUT
        try {
            Service__c debugLog = new Service__c();
            debugLog.Name = 'AI CALL ' + Datetime.now().format();
            debugLog.Email_Body__c = 'STATUS: ' + res.getStatusCode() + '\nUSER TEXT: ' + userText + '\nRESPONSE: ' + res.getBody() + '\nPROMPT LEN: ' + systemPrompt.length();
            debugLog.Whatsapp__c = true;
            insert debugLog;
        } catch(Exception eLog) {}

        if (res.getStatusCode() == 200) {
            Map<String, Object> resBody = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            List<Object> choices = (List<Object>) resBody.get('choices');
            if (choices != null && !choices.isEmpty()) {
                Map<String, Object> firstChoice = (Map<String, Object>) choices[0];
                Map<String, Object> msgObj = (Map<String, Object>) firstChoice.get('message');
                if (msgObj != null) {
                    return (String) msgObj.get('content');
                }
            }
        } 
        return null;
    }

    // ─── PARSE AI RESPONSE ────────────────────────────────────────────────
    private static VoiceResponse parseAIResponse(String aiContent, String userId) {
        VoiceResponse res = new VoiceResponse();
        res.isFallback = false;
        res.data = new Map<String, Object>();
        res.entries = new List<Map<String, Object>>();

        try {
            // Strip any markdown code blocks if AI wrapped it
            String cleaned = aiContent.trim();
            if (cleaned.startsWith('```')) {
                cleaned = cleaned.replaceAll('```[a-z]*\\n?', '').replaceAll('```', '').trim();
            }

            Map<String, Object> parsed = (Map<String, Object>) JSON.deserializeUntyped(cleaned);
            res.intent = (String) parsed.get('intent');
            res.message = (String) parsed.get('message');
            
            // Extract leave fields directly from top-level JSON
            res.leaveType = (String) parsed.get('leaveType');
            res.startDate = (String) parsed.get('startDate');
            res.endDate = (String) parsed.get('endDate');
            res.reason = (String) parsed.get('reason');

            // ── Parse entries array (multi-entry timesheet) ──
            Object entriesObj = parsed.get('entries');
            if (entriesObj instanceof List<Object>) {
                List<Object> entriesList = (List<Object>) entriesObj;
                for (Object entryObj : entriesList) {
                    if (entryObj instanceof Map<String, Object>) {
                        Map<String, Object> entryMap = (Map<String, Object>) entryObj;
                        Map<String, Object> cleanEntry = new Map<String, Object>();
                        for (String k : entryMap.keySet()) {
                            Object v = entryMap.get(k);
                            if (v != null) {
                                cleanEntry.put(k, v);
                            }
                        }
                        // Try to resolve projectId from projectName
                        if (cleanEntry.containsKey('projectName')) {
                            String pName = String.valueOf(cleanEntry.get('projectName'));
                            Project__c proj = findProjectByName(pName, userId);
                            if (proj != null) {
                                cleanEntry.put('projectId', proj.Id);
                                cleanEntry.put('projectName', proj.Name);
                            }
                        }
                        res.entries.add(cleanEntry);
                    }
                }
            }

            // Ensure projectId is also copied to 'data' for check-in/out if needed (backward compat)
            if (res.entries.size() == 1 && res.data.isEmpty()) {
                res.data.putAll(res.entries[0]);
            }

            // ── Parse legacy data map (for check_in, check_out, etc.) ──
            Object dataObj = parsed.get('data');
            if (dataObj instanceof Map<String, Object>) {
                Map<String, Object> dataMap = (Map<String, Object>) dataObj;
                for (String key : dataMap.keySet()) {
                    Object val = dataMap.get(key);
                    if (val != null && String.valueOf(val).trim() != '') {
                        res.data.put(key, val);
                    }
                }
            }

            // Backward compat: if entries is empty but data has projectName → wrap into entries
            if (res.entries.isEmpty() && 'log_timesheet'.equals(res.intent) && res.data.containsKey('projectName')) {
                Map<String, Object> singleEntry = new Map<String, Object>(res.data);
                res.entries.add(singleEntry);
            }

        } catch (Exception e) {
            System.debug('Failed to parse AI response: ' + e.getMessage() + ' | Raw: ' + aiContent);
            res.intent = 'unknown';
        }
        return res;
    }

    // ─── BUILD CONTEXT FOR AI ─────────────────────────────────────────────
    private static String buildContext(String userId) {
        // Fetch assigned projects
        List<String> projNames = new List<String>();
        for (Project_Assignment__c pa : [
            SELECT Project__r.Name FROM Project_Assignment__c
            WHERE Employee__c = :userId AND Project__c != null LIMIT 20
        ]) {
            if (pa.Project__r != null) projNames.add(pa.Project__r.Name);
        }

        // Fetch last timesheet entry
        String lastEntry = '';
        List<TimesheetEntry__c> recent = [
            SELECT Project__r.Name, Task__c, Date__c, Start_Time__c, End_Time__c
            FROM TimesheetEntry__c
            WHERE Timesheet__r.Employee__c = :userId
            ORDER BY Date__c DESC, CreatedDate DESC LIMIT 1
        ];
        if (!recent.isEmpty()) {
            TimesheetEntry__c t = recent[0];
            lastEntry = 'Last entry: Project=' + (t.Project__r != null ? t.Project__r.Name : '') +
                        ', Task=' + t.Task__c + ', Date=' + t.Date__c;
        }

        // Fetch available leave types
        List<String> leaveTypes = new List<String>();
        String yearStr = String.valueOf(Date.today().year());
        for (Employee_Leave_Balance__c lb : [
            SELECT Leave_Type__r.Leave_Type_Name__c 
            FROM Employee_Leave_Balance__c 
            WHERE Employee__c = :userId 
            AND Year__c = :yearStr
            AND Is_Eligible__c = true
            AND Is_Active__c = true
            LIMIT 10
        ]) {
            leaveTypes.add(lb.Leave_Type__r.Leave_Type_Name__c);
        }

        return 'Projects: [' + String.join(projNames, ', ') + ']. Leave Types: [' + String.join(leaveTypes, ', ') + ']. ' + lastEntry;
    }

    // ─── LOCAL FALLBACK LOGIC ─────────────────────────────────────────────
    private static VoiceResponse processLocally(String text, String userId) {
        VoiceResponse res = new VoiceResponse();
        res.data = new Map<String, Object>();
        res.isFallback = true;
        String lower = text.trim().toLowerCase();

        if (lower.contains('leave')) {
            if (lower.contains('cancel') || lower.contains('delete')) res.intent = 'cancel_leave';
            else if (lower.contains('update') || lower.contains('change')) res.intent = 'update_leave';
            else if (lower.contains('balance')) res.intent = 'leave_balance';
            else res.intent = 'apply_leave';

            // Common Extraction for Leave (Date + Reason)
            Pattern pDate = Pattern.compile('(?:on\\s+)?(january|february|march|april|may|june|july|august|september|october|november|december)\\s+(\\d{1,2})');
            Matcher mDate = pDate.matcher(lower);
            if (mDate.find()) {
                String monthName = mDate.group(1);
                String day = mDate.group(2);
                Map<String, String> months = new Map<String, String>{
                    'january'=>'01','february'=>'02','march'=>'03','april'=>'04','may'=>'05','june'=>'06',
                    'july'=>'07','august'=>'08','september'=>'09','october'=>'10','november'=>'11','december'=>'12'
                };
                String year = String.valueOf(Date.today().year());
                res.data.put('startDate', year + '-' + months.get(monthName) + '-' + (day.length()==1?'0'+day:day));
            }
            
            // NEW STRATEGY: Extract reason by looking for specific connectors AFTER the date
            String textAfterDate = '';
            Matcher mDateIdx = pDate.matcher(lower);
            if (mDateIdx.find()) {
                textAfterDate = lower.substring(mDateIdx.end()).trim();
            }

            // If we have text after the date, look for connectors there first
            if (String.isNotBlank(textAfterDate)) {
                Pattern pConn = Pattern.compile('(?i)^(?:that|because|as|to be|to|is|for|reason is)\\s*(.*)');
                Matcher mConn = pConn.matcher(textAfterDate);
                if (mConn.find()) {
                    res.data.put('reason', mConn.group(1).trim());
                } else {
                    // If no clear connector but there's text, it's probably the reason
                    // but skip small words like "the"
                    if (textAfterDate.length() > 5) res.data.put('reason', textAfterDate);
                }
            } else {
                // Fallback: look for "reason is", "because", "that" in the whole string
                Pattern pFallback = Pattern.compile('(?i)(?:reason is|because|that)\\s*(.*)');
                Matcher mFallback = pFallback.matcher(lower);
                if (mFallback.find()) {
                    res.data.put('reason', mFallback.group(1).trim());
                }
            }

            if (res.intent == 'apply_leave') {
                if (lower.contains('casual')) res.data.put('leaveType', 'Casual Leave');
                else if (lower.contains('sick')) res.data.put('leaveType', 'Sick Leave');
                else if (lower.contains('earned')) res.data.put('leaveType', 'Earned Leave');
            }
            return res;
        }
        if (lower.contains('balance')) {
            res.intent = 'leave_balance'; return res;
        }
        if (lower.contains('attendance') && (lower.contains('summary') || lower.contains('details'))) {
            res.intent = 'attendance_summary'; return res;
        }

        if (lower.contains('check') && lower.contains('in')) {
            res.intent = 'check_in'; return res;
        }
        if (lower.contains('check') && lower.contains('out')) {
            res.intent = 'check_out'; return res;
        }

        // Timesheet Fallback
        Boolean isTimesheet = lower.contains('timesheet') || lower.contains('log hour') || lower.contains('log time') || lower.contains('record time');
        Project__c proj = findProjectFuzzy(lower, userId);
        if (proj != null) { 
            isTimesheet = true; 
            res.data.put('projectId', proj.Id); 
            res.data.put('projectName', proj.Name); 
        }

        if (isTimesheet) {
            res.intent = 'log_timesheet';
            parseTimesheetDetails(lower, res.data);
            return res;
        }

        res.intent = 'unknown';
        return res;
    }

    // ─── HELPERS ──────────────────────────────────────────────────────────
    private static Boolean matches(String text, List<String> phrases) {
        for (String p : phrases) { if (text.contains(p)) return true; }
        return false;
    }

    private static Project__c findProjectFuzzy(String text, String userId) {
        for (Project_Assignment__c pa : [
            SELECT Project__c, Project__r.Id, Project__r.Name
            FROM Project_Assignment__c
            WHERE Employee__c = :userId AND Project__c != null
            ORDER BY CreatedDate DESC LIMIT 50
        ]) {
            if (pa.Project__r != null && text.contains(pa.Project__r.Name.toLowerCase())) {
                return pa.Project__r;
            }
        }
        return null;
    }

    private static Project__c findProjectByName(String name, String userId) {
        if (String.isBlank(name)) return null;
        String searchLower = name.toLowerCase();
        for (Project_Assignment__c pa : [
            SELECT Project__c, Project__r.Id, Project__r.Name
            FROM Project_Assignment__c
            WHERE Employee__c = :userId AND Project__c != null
            ORDER BY CreatedDate DESC LIMIT 50
        ]) {
            if (pa.Project__r != null && pa.Project__r.Name.toLowerCase().contains(searchLower)) {
                return pa.Project__r;
            }
        }
        return null;
    }

    private static void parseTimesheetDetails(String text, Map<String, Object> data) {
        // More robust duration: Look for number followed by hours anywhere
        Pattern pDuration = Pattern.compile('(\\d+(?:\\.\\d+)?)\\s*(?:hours?|hrs?)');
        Matcher mDuration = pDuration.matcher(text);
        if (mDuration.find()) {
            data.put('startTime', '09:00');
            Double hours = Double.valueOf(mDuration.group(1));
            Integer endHour = 9 + hours.intValue();
            String endMin = (Math.abs(hours - Math.floor(hours)) > 0.1) ? '30' : '00';
            data.put('endTime', (endHour > 9 ? String.valueOf(endHour) : '0' + endHour) + ':' + endMin);
        }
        
        // Task detection: anything after "doing" or "task is"
        Pattern pTask = Pattern.compile('(?:doing|task|activity|for|worked on)\\s*(?:is|was|:|which I\\s+\\w+\\s+is)?\\s*([\\w\\s\\-]+)');
        Matcher mTask = pTask.matcher(text);
        if (mTask.find()) {
            String t = mTask.group(1).trim().replaceAll('(?i)(from|at|since|worked|completed|using).*', '').trim();
            if (t.length() > 2) data.put('task', t);
        }
    }

    private static TimesheetEntry__c fetchLastTimesheet(String userId) {
        List<TimesheetEntry__c> recent = [
            SELECT Id, Project__c, Project__r.Name, Task__c, Date__c, Start_Time__c, End_Time__c
            FROM TimesheetEntry__c
            WHERE Timesheet__r.Employee__c = :userId
            ORDER BY Date__c DESC, CreatedDate DESC LIMIT 1
        ];
        return recent.isEmpty() ? null : recent[0];
    }
}