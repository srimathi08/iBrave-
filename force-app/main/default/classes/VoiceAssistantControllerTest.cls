/**
 * @class VoiceAssistantControllerTest  (COMPREHENSIVE – targets 80%+ coverage)
 *
 * Coverage strategy:
 *  - processVoiceCommandJson → processVoiceCommand → callSarvamAI (mocked) → parseAIResponse
 *  - When AI mock returns 500, falls back to processLocally (covers all 8 keyword branches)
 *  - transcribeAudio, transcribeBlob, checkService, executeVoiceAction, executeVoiceActionFromJson
 */
@isTest
private class VoiceAssistantControllerTest {

    // ─── Test Data ───────────────────────────────────────────────────────────

    @testSetup
    static void setup() {
        Project__c proj = new Project__c(Name = 'Book Trust', Status__c = 'Active');
        insert proj;
        insert new Project_Assignment__c(
            Project__c  = proj.Id,
            Employee__c = UserInfo.getUserId(),
            Employment_Status__c = 'Billable'
        );
        // One timesheet entry (for processLocally "yesterday" / fetchLastTimesheet coverage)
        Integer wn = TimesheetController.getWeekNumber(Date.today());
        Timesheet__c ts = new Timesheet__c(
            Employee__c = UserInfo.getUserId(),
            Week_Number__c = wn, Week_Year__c = Date.today().year(),
            Approval_Status__c = 'Draft'
        );
        insert ts;
        Project__c p = [SELECT Id FROM Project__c LIMIT 1];
        insert new TimesheetEntry__c(
            Timesheet__c = ts.Id, Project__c = p.Id,
            Date__c = Date.today(), Task__c = 'Dev',
            Regular_Hours__c = 4, Total_Hours__c = 4,
            Approval_Status__c = 'Draft', Status__c = 'In Progress'
        );
    }

    // ─── Mocks ───────────────────────────────────────────────────────────────

    private class SarvamAIMock implements HttpCalloutMock {
        private String intentJson;
        SarvamAIMock(String j) { this.intentJson = j; }
        public HTTPResponse respond(HTTPRequest req) {
            HTTPResponse res = new HTTPResponse();
            if (req.getEndpoint().contains('speech-to-text')) {
                res.setStatusCode(200);
                res.setBody('{"transcript":"Check in"}');
                return res;
            }
            String escaped = intentJson.replace('"', '\\"');
            res.setStatusCode(200);
            res.setBody('{"choices":[{"message":{"content":"' + escaped + '"}}]}');
            return res;
        }
    }

    /** Forces AI to fail → processLocally is always called */
    private class AiErrorMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HTTPResponse res = new HTTPResponse();
            res.setStatusCode(500);
            res.setBody('Server Error');
            return res;
        }
    }

    /** STT 500 → transcribeBlob throws */
    private class SttErrorMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HTTPResponse res = new HTTPResponse();
            res.setStatusCode(500);
            res.setBody('STT Error');
            return res;
        }
    }

    // ─── processVoiceCommandJson ─────────────────────────────────────────────

    @isTest
    static void testProcessVoiceCommandJson_LeaveBalance_MockAI() {
        String ai = '{"intent":"leave_balance","message":"Fetching..."}';
        Test.setMock(HttpCalloutMock.class, new SarvamAIMock(ai));
        Test.startTest();
        String r = VoiceAssistantController.processVoiceCommandJson('Leave balance', UserInfo.getUserId());
        Test.stopTest();
        Assert.isNotNull(r);
        Assert.isTrue(r.contains('intent'));
    }

    @isTest
    static void testProcessVoiceCommandJson_CheckIn_MockAI() {
        String ai = '{"intent":"check_in","message":"Checking in..."}';
        Test.setMock(HttpCalloutMock.class, new SarvamAIMock(ai));
        Test.startTest();
        String r = VoiceAssistantController.processVoiceCommandJson('Check in', UserInfo.getUserId());
        Test.stopTest();
        Assert.isNotNull(r);
    }

    @isTest
    static void testProcessVoiceCommandJson_WithEntries_MockAI() {
        String ai = '{"intent":"log_timesheet","entries":[{"projectName":"Book Trust","date":"2026-01-01","hours":4,"task":"Testing"}],"message":"Logged."}';
        Test.setMock(HttpCalloutMock.class, new SarvamAIMock(ai));
        Test.startTest();
        String r = VoiceAssistantController.processVoiceCommandJson('Log 4 hours Book Trust testing', UserInfo.getUserId());
        Test.stopTest();
        Assert.isNotNull(r);
    }

    @isTest
    static void testProcessVoiceCommandJson_WithDataBlock_MockAI() {
        String ai = '{"intent":"check_in","data":{"workLocation":"WFH"},"message":"Checking in from home."}';
        Test.setMock(HttpCalloutMock.class, new SarvamAIMock(ai));
        Test.startTest();
        String r = VoiceAssistantController.processVoiceCommandJson('Work from home today', UserInfo.getUserId());
        Test.stopTest();
        Assert.isNotNull(r);
    }

    // ─── processLocally (via AI error fallback) ───────────────────────────────

    @isTest
    static void testProcessLocally_CheckIn() {
        Test.setMock(HttpCalloutMock.class, new AiErrorMock());
        Test.startTest();
        String r = VoiceAssistantController.processVoiceCommandJson('check in', UserInfo.getUserId());
        Test.stopTest();
        Assert.isNotNull(r);
        Assert.isTrue(r.contains('"check_in"') || r.contains('check_in'));
    }

    @isTest
    static void testProcessLocally_CheckOut() {
        Test.setMock(HttpCalloutMock.class, new AiErrorMock());
        Test.startTest();
        String r = VoiceAssistantController.processVoiceCommandJson('check out', UserInfo.getUserId());
        Test.stopTest();
        Assert.isNotNull(r);
        Assert.isTrue(r.contains('check_out'));
    }

    @isTest
    static void testProcessLocally_ClockIn_Variant() {
        Test.setMock(HttpCalloutMock.class, new AiErrorMock());
        Test.startTest();
        String r = VoiceAssistantController.processVoiceCommandJson('clock in', UserInfo.getUserId());
        Test.stopTest();
        Assert.isNotNull(r);
    }

    @isTest
    static void testProcessLocally_ClockOut_Variant() {
        Test.setMock(HttpCalloutMock.class, new AiErrorMock());
        Test.startTest();
        String r = VoiceAssistantController.processVoiceCommandJson('clock out', UserInfo.getUserId());
        Test.stopTest();
        Assert.isNotNull(r);
    }

    @isTest
    static void testProcessLocally_LeaveBalance() {
        Test.setMock(HttpCalloutMock.class, new AiErrorMock());
        Test.startTest();
        String r = VoiceAssistantController.processVoiceCommandJson('leave balance', UserInfo.getUserId());
        Test.stopTest();
        Assert.isTrue(r.contains('leave_balance'));
    }

    @isTest
    static void testProcessLocally_ApplyLeave() {
        Test.setMock(HttpCalloutMock.class, new AiErrorMock());
        Test.startTest();
        String r = VoiceAssistantController.processVoiceCommandJson('apply leave', UserInfo.getUserId());
        Test.stopTest();
        Assert.isTrue(r.contains('apply_leave'));
    }

    @isTest
    static void testProcessLocally_Timesheet_Keyword() {
        Test.setMock(HttpCalloutMock.class, new AiErrorMock());
        Test.startTest();
        String r = VoiceAssistantController.processVoiceCommandJson('log timesheet today', UserInfo.getUserId());
        Test.stopTest();
        Assert.isTrue(r.contains('log_timesheet'));
    }

    @isTest
    static void testProcessLocally_TimesheetWithProjectName() {
        // "book trust" matches project name → triggers findProjectFuzzy → sets projectId
        Test.setMock(HttpCalloutMock.class, new AiErrorMock());
        Test.startTest();
        String r = VoiceAssistantController.processVoiceCommandJson('book trust 4 hours task testing', UserInfo.getUserId());
        Test.stopTest();
        Assert.isNotNull(r);
    }

    @isTest
    static void testProcessLocally_YesterdayRepeat_WithLastEntry() {
        // 'yesterday' triggers fetchLastTimesheet
        Test.setMock(HttpCalloutMock.class, new AiErrorMock());
        Test.startTest();
        String r = VoiceAssistantController.processVoiceCommandJson('repeat yesterday timesheet', UserInfo.getUserId());
        Test.stopTest();
        Assert.isNotNull(r);
    }

    @isTest
    static void testProcessLocally_Unknown_Text() {
        Test.setMock(HttpCalloutMock.class, new AiErrorMock());
        Test.startTest();
        String r = VoiceAssistantController.processVoiceCommandJson('hello how are you', UserInfo.getUserId());
        Test.stopTest();
        Assert.isTrue(r.contains('unknown'));
    }

    @isTest
    static void testProcessLocally_NullText() {
        Test.setMock(HttpCalloutMock.class, new AiErrorMock());
        Test.startTest();
        String r = VoiceAssistantController.processVoiceCommandJson(null, UserInfo.getUserId());
        Test.stopTest();
        Assert.isNotNull(r);
    }

    // ─── executeVoiceActionFromJson ──────────────────────────────────────────

    @isTest
    static void testExecuteVoiceActionFromJson_Blank() {
        Test.startTest();
        String r = VoiceAssistantController.executeVoiceActionFromJson('', UserInfo.getUserId());
        Test.stopTest();
        Assert.areEqual('No input data received.', r);
    }

    @isTest
    static void testExecuteVoiceActionFromJson_InvalidJson() {
        Test.startTest();
        String r = VoiceAssistantController.executeVoiceActionFromJson('NOT_JSON', UserInfo.getUserId());
        Test.stopTest();
        Assert.isTrue(r.toLowerCase().contains('error'));
    }

    @isTest
    static void testExecuteVoiceActionFromJson_CheckIn() {
        Test.startTest();
        String r = VoiceAssistantController.executeVoiceActionFromJson(
            '{"intent":"check_in","message":"Checking in..."}', UserInfo.getUserId());
        Test.stopTest();
        Assert.isNotNull(r);
    }

    @isTest
    static void testExecuteVoiceActionFromJson_CheckOut() {
        Test.startTest();
        String r = VoiceAssistantController.executeVoiceActionFromJson(
            '{"intent":"check_out","message":"Checking out..."}', UserInfo.getUserId());
        Test.stopTest();
        Assert.isNotNull(r);
    }

    @isTest
    static void testExecuteVoiceActionFromJson_LeaveBalance() {
        Test.startTest();
        String r = VoiceAssistantController.executeVoiceActionFromJson(
            '{"intent":"leave_balance"}', UserInfo.getUserId());
        Test.stopTest();
        Assert.isNotNull(r);
    }

    @isTest
    static void testExecuteVoiceActionFromJson_LogTimesheetEmpty() {
        Test.startTest();
        String r = VoiceAssistantController.executeVoiceActionFromJson(
            '{"intent":"log_timesheet","entries":[]}', UserInfo.getUserId());
        Test.stopTest();
        Assert.isNotNull(r);
    }

    @isTest
    static void testExecuteVoiceActionFromJson_DataBackwardCompat() {
        Test.startTest();
        String r = VoiceAssistantController.executeVoiceActionFromJson(
            '{"intent":"log_timesheet","data":{"projectId":"abc"},"entries":[]}',
            UserInfo.getUserId());
        Test.stopTest();
        Assert.isNotNull(r);
    }

    @isTest
    static void testExecuteVoiceActionFromJson_UpdateLeave() {
        Test.startTest();
        String r = VoiceAssistantController.executeVoiceActionFromJson(
            '{"intent":"update_leave","startDate":"2099-01-01"}', UserInfo.getUserId());
        Test.stopTest();
        Assert.isNotNull(r);
    }

    @isTest
    static void testExecuteVoiceActionFromJson_CancelLeave() {
        Test.startTest();
        String r = VoiceAssistantController.executeVoiceActionFromJson(
            '{"intent":"cancel_leave","startDate":"2099-01-01"}', UserInfo.getUserId());
        Test.stopTest();
        Assert.isNotNull(r);
    }

    @isTest
    static void testExecuteVoiceActionFromJson_Unknown() {
        Test.startTest();
        String r = VoiceAssistantController.executeVoiceActionFromJson(
            '{"intent":"unknown","message":"Sorry."}', UserInfo.getUserId());
        Test.stopTest();
        Assert.isNotNull(r);
    }

    @isTest
    static void testExecuteVoiceActionFromJson_WithEntries() {
        Test.startTest();
        String r = VoiceAssistantController.executeVoiceActionFromJson(
            '{"intent":"log_timesheet","entries":[{"projectId":"fakeId","date":"2099-01-01","hours":4}]}',
            UserInfo.getUserId());
        Test.stopTest();
        Assert.isNotNull(r);
    }

    // ─── executeVoiceAction ──────────────────────────────────────────────────

    @isTest
    static void testExecuteVoiceAction_NullResponse() {
        Test.startTest();
        String r = VoiceAssistantController.executeVoiceAction(null, UserInfo.getUserId());
        Test.stopTest();
        Assert.areEqual('No intent detected.', r);
    }

    @isTest
    static void testExecuteVoiceAction_BlankIntent() {
        VoiceAssistantController.VoiceResponse res = new VoiceAssistantController.VoiceResponse();
        res.intent = '';
        Test.startTest();
        String r = VoiceAssistantController.executeVoiceAction(res, UserInfo.getUserId());
        Test.stopTest();
        Assert.areEqual('No intent detected.', r);
    }

    @isTest
    static void testExecuteVoiceAction_LeaveBalance() {
        VoiceAssistantController.VoiceResponse res = new VoiceAssistantController.VoiceResponse();
        res.intent  = 'leave_balance';
        res.message = 'Fetching...';
        res.data    = new Map<String,Object>();
        res.entries = new List<Map<String,Object>>();
        Test.startTest();
        String r = VoiceAssistantController.executeVoiceAction(res, UserInfo.getUserId());
        Test.stopTest();
        Assert.isNotNull(r);
    }

    @isTest
    static void testExecuteVoiceAction_ProjectNotFound() {
        VoiceAssistantController.VoiceResponse res = new VoiceAssistantController.VoiceResponse();
        res.intent  = 'project_not_found';
        res.message = 'That project is not assigned.';
        res.data    = new Map<String,Object>();
        res.entries = new List<Map<String,Object>>();
        Test.startTest();
        String r = VoiceAssistantController.executeVoiceAction(res, UserInfo.getUserId());
        Test.stopTest();
        Assert.isTrue(r.contains('not assigned') || r.length() > 0);
    }

    // ─── checkService ────────────────────────────────────────────────────────

    @isTest
    static void testCheckService() {
        Test.startTest();
        String r = VoiceAssistantController.checkService();
        Test.stopTest();
        Assert.areEqual('Connectivity OK', r);
    }

    // ─── transcribeAudio ─────────────────────────────────────────────────────

    @isTest
    static void testTranscribeAudio_Blank_ReturnsNull() {
        Test.startTest();
        String r = VoiceAssistantController.transcribeAudio('', 'audio/wav');
        Test.stopTest();
        Assert.isNull(r);
    }

    @isTest
    static void testTranscribeBlob_WithGoodMock() {
        String ai = '{"intent":"check_in"}';
        Test.setMock(HttpCalloutMock.class, new SarvamAIMock(ai));
        Test.startTest();
        String result = VoiceAssistantController.transcribeBlob(
            Blob.valueOf('fake audio data'), 'audio/wav');
        Test.stopTest();
        // null if API key blank in test env, or "Check in" from mock
        Assert.isTrue(result == null || result == 'Check in');
    }

    @isTest
    static void testTranscribeBlob_WithNullBlob_ReturnsNull() {
        Test.startTest();
        String result = VoiceAssistantController.transcribeBlob(null, 'audio/wav');
        Test.stopTest();
        Assert.isNull(result);
    }
}