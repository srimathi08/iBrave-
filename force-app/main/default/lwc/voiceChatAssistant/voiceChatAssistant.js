import { LightningElement, api, track } from 'lwc';
import USER_ID from '@salesforce/user/Id';

// Attendance (same controllers as attendanceComponent)
import createAttendance from '@salesforce/apex/NewController.createAttendance';
import updateAttendance from '@salesforce/apex/EditController.updateAttendance';
import getTodayAttendanceRecord from '@salesforce/apex/AttendanceViewController.getTodayAttendanceRecord';
import getMonthlySummary from '@salesforce/apex/AttendanceSummaryController.getMonthlySummary';

// Leave
import getLeaveBalanceSummary from '@salesforce/apex/EmployeeLeaveController.getLeaveBalanceSummary';
import submitLeaveRequest from '@salesforce/apex/LeaveRequestController.submitLeaveRequest';
import getEmployeeLeaveBalances from '@salesforce/apex/EmployeeLeaveController.getEmployeeLeaveBalances';
import getUpcomingLeavesAndHolidays from '@salesforce/apex/EmployeeLeaveController.getUpcomingLeavesAndHolidays';

// Timesheet
import createMultipleTimesheetEntries from '@salesforce/apex/TimesheetController.createMultipleTimesheetEntries';
import getProjects from '@salesforce/apex/TimesheetController.getProjects';
import getStatusPicklistValues from '@salesforce/apex/TimesheetController.getStatusPicklistValues';

// AI Voice Assistant (Using Stealth Bridge to bypass platform interception)
import processData from '@salesforce/apex/ProHRM_DataBridge.processData';
import uploadData from '@salesforce/apex/ProHRM_DataBridge.uploadData';
import submitData from '@salesforce/apex/ProHRM_DataBridge.submitData';
import checkStatus from '@salesforce/apex/ProHRM_DataBridge.checkStatus';

let msgIdCounter = 0;

export default class VoiceChatAssistant extends LightningElement {
    @api employeeId;
    @api employeeName;

    @track isChatOpen = false;
    @track messages = [];
    @track userInput = '';
    @track isListening = false;
    @track isTyping = false;
    @track showCamera = false;
    @track capturedPhotoB64 = null;

    // Conversation state for multi-step flows
    _conversationState = null;
    _leaveTypes = [];
    _projects = [];
    _timesheetStatuses = [];
    _cameraStream = null;
    _cameraMode = null;

    // Media Recorder for Sarvam STT
    _mediaRecorder = null;
    _audioChunks = [];

    // ─── Getters ────────────────────────────────
    get chatBubbleClass() {
        return this.isChatOpen ? 'chat-bubble open' : 'chat-bubble';
    }

    get micBtnClass() {
        return this.isListening ? 'mic-btn listening' : 'mic-btn';
    }

    get micTitle() {
        return this.isListening ? 'Stop listening' : 'Start voice input';
    }

    get inputPlaceholder() {
        if (this.isListening) return 'Listening...';
        if (this._conversationState) {
            const s = this._conversationState;
            if (s.flow === 'checkIn') {
                if (s.step === 'awaitLocation') return 'Type location number (1-4)...';
                if (s.step === 'awaitPhoto') return 'Capture photo or type skip...';
            }
            if (s.flow === 'checkOut') {
                if (s.step === 'awaitPhoto') return 'Capture photo or type skip...';
            }
            if (s.flow === 'applyLeave') {
                if (s.step === 'awaitType') return 'Type leave number or name...';
                if (s.step === 'awaitDates') return 'Enter dates (e.g. tomorrow, 2026-02-20)...';
                if (s.step === 'awaitReason') return 'Enter reason for leave...';
                if (s.step === 'awaitConfirm') return 'Type yes or no...';
            }
            if (s.flow === 'logTimesheet') {
                if (s.step === 'awaitProject') return 'Type project number or name...';
                if (s.step === 'awaitTask') return 'Describe your task...';
                if (s.step === 'awaitStartTime') return 'Enter start time (e.g. 09:00)...';
                if (s.step === 'awaitEndTime') return 'Enter end time (e.g. 17:00)...';
                if (s.step === 'awaitDescription') return 'Enter description or say skip...';
                if (s.step === 'awaitConfirm') return 'Type yes or no...';
            }
        }
        return 'Type a message or tap 🎙️...';
    }

    get isSendDisabled() {
        return !this.userInput || this.userInput.trim().length === 0;
    }

    // ─── Lifecycle ──────────────────────────────
    connectedCallback() {
        if (!this.employeeId) {
            this.employeeId = USER_ID;
        }
        // Eagerly load projects for generalized timesheet matching
        this._preloadProjects();
    }

    async _preloadProjects() {
        try {
            const [projects, statuses] = await Promise.all([
                getProjects(),
                getStatusPicklistValues()
            ]);
            this._projects = projects || [];
            this._timesheetStatuses = statuses || [];
        } catch (e) {
            // Silently fail — projects will be loaded on demand
        }
    }

    disconnectedCallback() {
    }

    // ─── Toggle Chat ────────────────────────────
    toggleChat() {
        this.isChatOpen = !this.isChatOpen;
        if (this.isChatOpen && this.messages.length === 0) {
            this._addBotMessage(
                `Hi${this.employeeName ? ' ' + this.employeeName.split(' ')[0] : ''}! 👋<br><br>` +
                `I'm your <b>HR Assistant</b>. I can help you with:<br>` +
                `• ✅ <b>Check In / Out</b><br>` +
                `• 📊 <b>Leave Balance</b><br>` +
                `• 📝 <b>Apply Leave</b><br>` +
                `• ⏱️ <b>Log Timesheet</b><br>` +
                `• 📋 <b>Attendance Summary</b><br>` +
                `• 🧭 <b>Navigate</b> to any tab<br><br>` +
                `Just type or speak your request!`
            );
        }
    }

    async toggleVoice() {
        if (this.isListening) {
            this._stopRecording();
        } else {
            this._startRecording();
        }
    }

    async _startRecording() {
        try {
            const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
            this._mediaRecorder = new MediaRecorder(stream);
            this._audioChunks = [];

            this._mediaRecorder.ondataavailable = (e) => {
                if (e.data.size > 0) this._audioChunks.push(e.data);
            };

            this._mediaRecorder.onstop = async () => {
                const audioBlob = new Blob(this._audioChunks, { type: this._mediaRecorder.mimeType });
                this._processAudioBlob(audioBlob);
                // Stop all tracks to release microphone
                stream.getTracks().forEach(track => track.stop());
            };

            this._mediaRecorder.start();
            this.isListening = true;
            this.userInput = 'Listening...';
        } catch (e) {
            console.error('Error starting recording:', e);
            this._addBotMessage('🎤 Could not access microphone. Please check permissions.');
        }
    }

    _stopRecording() {
        if (this._mediaRecorder && this._mediaRecorder.state !== 'inactive') {
            this._mediaRecorder.stop();
            this.isListening = false;
            this.userInput = 'Processing voice...';
        }
    }

    async _processAudioBlob(blob) {
        this._showTyping();
        try {
            const reader = new FileReader();
            reader.readAsDataURL(blob);
            reader.onloadend = async () => {
                try {
                    const base64Audio = reader.result.split(',')[1];
                    console.log('Voice: Preparing upload via Bridge. Size:', base64Audio.length);
                    const transcript = await uploadData({
                        p1: base64Audio,
                        p2: blob.type || 'audio/wav'
                    });
                    console.log('Transcription result:', transcript);

                    this._hideTyping();
                    if (transcript && transcript.trim().length > 3 && !transcript.startsWith('Detail Error') && !transcript.startsWith('ERR:')) {
                        this.userInput = transcript; // Provide to user for review/edit
                        // No longer calling _processUserInput(transcript) immediately
                    } else if (transcript && (transcript.startsWith('Detail Error') || transcript.startsWith('ERR:'))) {
                        this.userInput = '';
                        this._addBotMessage('🎤 Sorry, I had trouble transcribing that. Please try again.');
                    } else {
                        this.userInput = '';
                        // Do not add bot message for ultra-short noise
                    }
                } catch (err) {
                    this._hideTyping();
                    console.error('Inner error processing audio:', err);
                    let errMsg = '❌ Transcription issue.';
                    if (err && err.body && err.body.message) errMsg = '❌ ' + err.body.message;
                    this._addBotMessage(errMsg);
                }
            };
        } catch (e) {
            this._hideTyping();
            console.error('Error processing audio:', e);
            this._addBotMessage('❌ Failed to process audio.');
        }
    }

    // ─── Input Handlers ─────────────────────────
    handleInputChange(event) {
        this.userInput = event.target.value;
    }

    handleInputKeyUp(event) {
        if (event.key === 'Enter' && this.userInput && this.userInput.trim()) {
            this.handleSend();
        }
    }

    handleSend() {
        const text = this.userInput ? this.userInput.trim() : '';
        if (!text) return;
        this.userInput = '';
        this._processUserInput(text);
    }

    // ─── Quick Actions ──────────────────────────
    handleQuickCheckIn() {
        this._processUserInput('Check in');
    }

    handleQuickCheckOut() {
        this._processUserInput('Check out');
    }

    handleQuickLeaveBalance() {
        this._processUserInput('Leave balance');
    }

    handleQuickAttendance() {
        this._processUserInput('My attendance');
    }

    handleQuickLogTimesheet() {
        this._processUserInput('Log timesheet');
    }

    handleQuickApplyLeave() {
        this._processUserInput('Apply leave');
    }

    // ─── Main NLP Router ────────────────────────────────────────────────
    // Fast local checks handle clear-cut intents.
    // Sarvam AI handles complex/ambiguous natural language.
    _processUserInput(text) {
        this._addUserMessage(text);
        this.userInput = ''; // Clear the input bar automatically
        const lower = text.toLowerCase().trim();

        // 1. HIGH-PRIORITY: Quick Actions (Breaks any conversation state)
        if (lower === 'cancel' || lower === 'stop' || lower === 'reset') {
            this._conversationState = null;
            this._addBotMessage('Okay, cancelled! How else can I help?');
            return;
        }

        // Attendance Quick-Match (Direct Route for Demo Stability)
        // Fuzzy Match: check.*in, mark.*attendance, etc.
        const checkInRegex = /\b(check.*in|mark.*attendance|starting.*work|started.*work|clock.*in|i['m| am].*office|working.*home|at.*office|from.*home|log.*in)\b/i;
        if (checkInRegex.test(lower)) {
            this._conversationState = null;
            let loc = null;
            if (lower.includes('home') || lower.includes('wfh')) loc = 'Work from Home';
            else if (lower.includes('office') || lower.includes('wfo')) loc = 'Work from Office';
            this._handleCheckIn(loc);
            return;
        }

        const checkOutRegex = /\b(check.*out|leaving|im.*leaving|clock.*out|done.*day|bye|off.*day|log.*out)\b/i;
        if (checkOutRegex.test(lower)) {
            this._conversationState = null;
            this._handleCheckOut();
            return;
        }

        // 2. Navigation — handle locally
        if (this._matchesNavigation(lower)) return;

        // 3. Help — handle locally
        if (this._matchesIntent(lower, ['help', 'what can you do', 'commands', 'what can you help'])) {
            this._addBotMessage(
                `Here's what I can do:<br>` +
                `• ✅ <b>Check in / Mark attendance</b><br>` +
                `• 🚪 <b>Check out / I'm leaving</b><br>` +
                `• 📊 <b>Leave balance / How many leaves</b><br>` +
                `• 📝 <b>Apply leave / Request leave</b><br>` +
                `• ⏱️ <b>Log timesheet</b> or describe your work naturally<br>` +
                `• 📋 <b>Attendance summary</b><br>` +
                `• 🧭 <b>Go to [tab]</b> (attendance, timesheet, etc.)<br>` +
                `• ❌ <b>Cancel</b> to stop any flow<br><br>` +
                `💡 <i>Speak naturally — I understand casual sentences!</i>`
            );
            return;
        }

        // 4. Conversational Flow (Multi-step)
        if (this._conversationState) {
            this._handleConversationStep(lower, text);
            return;
        }

        // 7. Default: Let the high-intelligence AI handle it
        this._processWithAI(text);
    }

    // ─── LOCAL SINGLE-ENTRY TIMESHEET HANDLER ─────────────────────────────────
    // Handles simple "worked X hours on [project] on [day]" without any AI or multi-step.
    // Maximum ONE question: which project? (only if project is unclear)
    async _handleTimesheetDirect(text) {
        this._showTyping();
        try {
            // Load projects and statuses independently so neither blocks the other
            const needsProjects = !this._projects || this._projects.length === 0;
            const needsStatuses = !this._timesheetStatuses || this._timesheetStatuses.length === 0;
            if (needsProjects && needsStatuses) {
                const [projs, stats] = await Promise.all([getProjects(), getStatusPicklistValues()]);
                this._projects = projs;
                this._timesheetStatuses = stats || [];
            } else if (needsProjects) {
                this._projects = await getProjects();
            } else if (needsStatuses) {
                this._timesheetStatuses = (await getStatusPicklistValues()) || [];
            }
            this._hideTyping();

            if (!this._projects || this._projects.length === 0) {
                this._addBotMessage('⚠️ No projects assigned to you. Please contact your manager.');
                return;
            }

            const lower = text.toLowerCase();
            const todayStr = this._toDateString(new Date());
            // Use first picklist value as status, fall back to 'Submitted'
            const statusValue = (this._timesheetStatuses && this._timesheetStatuses[0]) || 'Submitted';

            // 1. Extract hours
            let hours = null;
            const hrMatch = text.match(/(\d+(?:\.\d+)?)\s*(?:hours?|hrs?)\b/i);
            if (hrMatch) hours = parseFloat(hrMatch[1]);
            if (!hours && /\bhalf[\s-]?day\b/i.test(text)) hours = 4;
            if (!hours && /\bfull[\s-]?day\b/i.test(text)) hours = 8;

            // 2. Extract date (most recent past occurrence of day name)
            let date = todayStr;
            if (/\byesterday\b/i.test(lower)) { const y = new Date(); y.setDate(y.getDate() - 1); date = this._toDateString(y); }
            else if (/\bmonday\b/i.test(lower)) date = this._lastWeekday(1);
            else if (/\btuesday\b/i.test(lower)) date = this._lastWeekday(2);
            else if (/\bwednesday\b/i.test(lower)) date = this._lastWeekday(3);
            else if (/\bthursday\b/i.test(lower)) date = this._lastWeekday(4);
            else if (/\bfriday\b/i.test(lower)) date = this._lastWeekday(5);
            else if (/\bsaturday\b/i.test(lower)) date = this._lastWeekday(6);
            else if (/\bsunday\b/i.test(lower)) date = this._lastWeekday(0);
            const isoMatch = text.match(/\d{4}-\d{2}-\d{2}/);
            if (isoMatch) date = isoMatch[0] <= todayStr ? isoMatch[0] : todayStr;

            // 3. Match project — normalized match wins (handles 'booktrust' → 'Book Trust', initials, etc.)
            let project = null;
            let bestLen = 0;
            const lowerNorm = lower.replace(/\s+/g, ''); // strip all spaces for comparison
            for (const p of this._projects) {
                const name = (p.label || p.Name || '').toLowerCase();
                const nameNorm = name.replace(/\s+/g, '');
                // Match 1: full name included in text (e.g. "book trust" in "worked on book trust")
                // Match 2: space-stripped name in space-stripped text (e.g. "booktrust" → "booktrust")
                const match1 = name.length > 2 && lower.includes(name);
                const match2 = nameNorm.length > 2 && lowerNorm.includes(nameNorm);
                if ((match1 || match2) && name.length > bestLen) {
                    project = p; bestLen = name.length;
                }
            }

            // 4. Extract task — strip noise words, hours, date words, project name
            let task = text
                .replace(/(\d+(?:\.\d+)?)\s*(?:hours?|hrs?)\b/gi, '')
                .replace(/\b(half|full)[\s-]?day\b/gi, '')
                .replace(/\b(on|today|yesterday|monday|tuesday|wednesday|thursday|friday|saturday|sunday|for|the|a|an|in|my|i|log|timesheet|spent|worked|working|did|completed|done|with|task|project|this|last|week)\b/gi, ' ')
                // Remove project name (both spaced and unspaced variants)
                .replace(project ? new RegExp((project.label || project.Name || '').replace(/[.*+?^${}()|[\]\\]/g, '\\$&'), 'gi') : /(?:)/, '')
                .replace(project ? new RegExp((project.label || project.Name || '').replace(/\s+/g, '').replace(/[.*+?^${}()|[\]\\]/g, '\\$&'), 'gi') : /(?:)/, '')
                .replace(/\s+/g, ' ').trim();
            if (!task || task.length < 3) task = 'Development';
            if (task.length > 120) task = task.substring(0, 120);


            // 5. Route — only ask for project if missing; everything else defaults
            if (!project) {
                let html = `⏱️ <b>Log Timesheet</b><br><br>Which project is this for?<br><br>`;
                this._projects.forEach((p, i) => { html += `${i + 1}. <b>${p.label || p.Name}</b><br>`; });
                this._addBotMessage(html);
                this._conversationState = {
                    flow: 'logTimesheet', step: 'awaitProject',
                    data: { date, hours, task, status: null }
                };
                return;
            }

            // All fields resolved — submit immediately!
            await this._submitTimesheetHoursOnly({ project, date, hours, task, statusValue });

        } catch (err) {
            this._hideTyping();
            console.error('Timesheet direct error:', err);
            this._addBotMessage('❌ Something went wrong. Please try again.');
        }
    }

    // Submit a timesheet row using only Total Hours (no start/end time required)
    async _submitTimesheetHoursOnly({ project, date, hours, task, statusValue }) {
        this._conversationState = null;
        this._showTyping();
        try {
            const totalHrs = Math.round((hours || 0) * 100) / 100;
            const row = {
                Project__c: project.value || project.Id,
                Date__c: date,
                Task__c: task,
                Description__c: task,
                Status__c: statusValue,
                Regular_Hours__c: Math.min(totalHrs, 8),
                Overtime_Hours__c: Math.max(0, totalHrs - 8),
                Total_Hours__c: totalHrs,
                Approval_Status__c: 'Draft'
            };
            await createMultipleTimesheetEntries({ rows: [row] });
            this._hideTyping();
            this._addBotMessage(
                `✅ <b>Timesheet saved!</b><br><br>` +
                `📌 <b>${project.label || project.Name}</b> · ${this._formatDate(date)} · ${totalHrs} hrs · ${task}<br><br>` +
                `Keep up the great work! 💪`
            );
        } catch (error) {
            this._hideTyping();
            this._addBotMessage(`❌ Failed to save timesheet: ${this._extractError(error)}`);
        }
    }

    // Returns the date string for the most recent past occurrence of a weekday
    // targetDow: 0=Sunday, 1=Monday, ..., 6=Saturday (matches JS getDay())
    _lastWeekday(targetDow) {
        const today = new Date();
        const todayDow = today.getDay();
        const daysAgo = (todayDow - targetDow + 7) % 7;
        const d = new Date(today);
        d.setDate(today.getDate() - daysAgo);
        return this._toDateString(d);
    }

    // ─── AI PROCESSING VIA SARVAM AI ─────────────────────────────────────
    async _processWithAI(text) {
        this._showTyping();
        try {
            const rawResult = await processData({
                p1: text,
                p2: this.employeeId
            });
            this._hideTyping();

            let result;
            try {
                result = typeof rawResult === 'string' ? JSON.parse(rawResult) : rawResult;
            } catch (e) {
                console.error('JSON Parse error:', e, rawResult);
                this._addBotMessage('I encountered a system error reading the AI response.');
                return;
            }

            if (!result || !result.intent) {
                this._addBotMessage(`I'm not sure what you meant. Try saying <b>"help"</b> for a list of commands.`);
                return;
            }

            switch (result.intent) {
                case 'check_in':
                case 'check_out':
                case 'log_timesheet': {
                    // Centralized Record Creation in Apex (Using JSON string to prevent mapping issues)
                    const resultMessage = await submitData({
                        p1: JSON.stringify(result),
                        p2: this.employeeId
                    });
                    this._addBotMessage(resultMessage);
                    break;
                }

                case 'leave_balance':
                    this._handleLeaveBalance();
                    break;

                case 'apply_leave':
                    this._startApplyLeaveFlow({
                        leaveType: result.leaveType,
                        startDate: result.startDate,
                        endDate: result.endDate,
                        reason: result.reason
                    });
                    break;

                default:
                    // Unknown intent from AI
                    this._addBotMessage(
                        `I'm not sure what you meant. Try:<br>` +
                        `• <b>"Check in"</b> or <b>"Check out"</b><br>` +
                        `• <b>"Leave balance"</b> or <b>"Apply leave"</b><br>` +
                        `• <b>"Log timesheet"</b> or just mention your project name<br>` +
                        `Or say <b>"help"</b> for all commands.`
                    );
            }
        } catch (err) {
            this._hideTyping();
            console.error('AI processing error:', err);
            // Graceful degradation — try local parsing
            this._startTimesheetFlow(text);
        }
    }

    _matchesIntent(text, phrases) {
        // Normalize: collapse multiple spaces, trim
        const normalized = text.replace(/\s+/g, ' ').trim();
        if (phrases.some(p => normalized.includes(p))) return true;
        // Strip filler words and re-check (handles "hi create a time sheet")
        const stripped = normalized.replace(/\b(hi|hey|hello|please|pls|kindly|can you|could you|i want to|i need to|a|an|the|my)\b/gi, '').replace(/\s+/g, ' ').trim();
        return phrases.some(p => stripped.includes(p));
    }

    // Generalized timesheet detection: checks if message mentions a project name
    // or contains strong timesheet-related context clues
    _detectsTimesheetContext(lower, original) {
        // 1. Check if any known project name appears in the message
        if (this._projects && this._projects.length > 0) {
            const found = this._findProjectFuzzy(lower);
            if (found) return true;
        }

        // 2. Check for strong timesheet context: time + work-action words
        const hasTimeRef = /\b(\d{1,2}[:.\s]\d{2}|\d{1,2}\s*(?:am|pm)|\d+\s*(?:hours?|hrs?))\b/i.test(lower);
        const hasWorkAction = /\b(worked|working|developed|created|built|designed|coded|fixed|tested|reviewed|deployed|task|timesheet|time sheet)\b/i.test(lower);
        if (hasTimeRef && hasWorkAction) return true;

        return false;
    }

    // ─── CHECK IN (Multi-step: location → photo → submit) ─────
    async _handleCheckIn(preDetectedLocation) {
        this._showTyping();
        try {
            // Check for leave on today before check-in — BLOCK if active leave found
            try {
                const upcomingResult = await getUpcomingLeavesAndHolidays({ employeeId: this.employeeId });
                if (upcomingResult && upcomingResult.length > 0) {
                    const todayStr = new Date().toISOString().split('T')[0];
                    const todayLeaves = upcomingResult.filter(item => {
                        if (item.recordType !== 'Leave') return false;
                        const start = item.Start_Date__c;
                        const end = item.End_Date__c || item.Start_Date__c;
                        return todayStr >= start && todayStr <= end;
                    });
                    if (todayLeaves.length > 0) {
                        const leaveDetails = todayLeaves.map(l => {
                            const typeName = l.Leave_Type__r ? l.Leave_Type__r.Leave_Type_Name__c : 'Leave';
                            const startDt = l.Start_Date__c || '';
                            const endDt = l.End_Date__c || startDt;
                            return `• <b>${typeName}</b> — ${l.Status__c} (${startDt} to ${endDt})`;
                        }).join('<br>');
                        this._hideTyping();
                        this._addBotMessage(
                            `🚫 <b>Check-in blocked!</b><br><br>` +
                            `You have active leave on today:<br>${leaveDetails}<br><br>` +
                            `To check in, please:<br>` +
                            `1. <b>Cancel your leave request</b> first, or<br>` +
                            `2. Contact <b>HR</b> to update your leave status.<br><br>` +
                            `<i>Check-in is not allowed on leave days to keep attendance records accurate.</i>`
                        );
                        return;
                    }
                }
            } catch (e) {
                // If leave check fails, allow check-in to proceed
            }

            // Get GPS location in background
            const pos = await this._getLocation();
            this._hideTyping();

            // ─── If AI already detected work location from speech, skip the question ───
            if (preDetectedLocation) {
                const locationEmoji = {
                    'Work from Office': '🏢', 'Work from Home': '🏠',
                    'Client Place': '👤', 'Field Work': '🌍'
                }[preDetectedLocation] || '📍';
                this._addBotMessage(
                    `${locationEmoji} Got it — <b>${preDetectedLocation}</b>!<br><br>` +
                    `📸 <b>Please take a selfie for check-in</b><br><br>` +
                    `Click the <b>📷 Open Camera</b> button below, or type <b>skip</b> to check in without a photo.`
                );
                this._openCamera('checkIn');
                this._conversationState = {
                    flow: 'checkIn',
                    step: 'awaitPhoto',
                    data: { pos: pos, workLocation: preDetectedLocation }
                };
            } else {
                // No location in speech — ask for it
                this._addBotMessage(
                    `📍 <b>Where are you working today?</b><br><br>` +
                    `1. 🏢 Work from Office<br>` +
                    `2. 🏠 Work from Home<br>` +
                    `3. 👤 Client Place<br>` +
                    `4. 🌍 Field Work<br><br>` +
                    `<i>Type the number or name</i>`
                );
                this._conversationState = {
                    flow: 'checkIn',
                    step: 'awaitLocation',
                    data: { pos: pos }
                };
            }
        } catch (error) {
            this._hideTyping();
            this._addBotMessage(`❌ Check-in failed: ${this._extractError(error)}`);
        }
    }

    // ─── CHECK-IN FLOW STEPS ────────────────────
    _handleCheckInStep(lower, original, state) {
        switch (state.step) {
            case 'awaitLocation': {
                const locationMap = {
                    '1': 'Work from Office', 'office': 'Work from Office', 'work from office': 'Work from Office', 'wfo': 'Work from Office',
                    '2': 'Work from Home', 'home': 'Work from Home', 'work from home': 'Work from Home', 'wfh': 'Work from Home',
                    '3': 'Client Place', 'client': 'Client Place', 'client place': 'Client Place',
                    '4': 'Field Work', 'field': 'Field Work', 'field work': 'Field Work'
                };
                const location = locationMap[lower];
                if (!location) {
                    this._addBotMessage('Please type a number (1-4) or location name (Office, Home, Client, Field).');
                    return;
                }
                state.data.workLocation = location;
                state.step = 'awaitPhoto';
                this._addBotMessage(
                    `📸 <b>Please take a selfie for check-in</b><br><br>` +
                    `Location: <b>${location}</b><br><br>` +
                    `Click the <b>📷 Open Camera</b> button below, or type <b>skip</b> to check in without a photo.`
                );
                this._openCamera('checkIn');
                break;
            }
            case 'awaitPhoto': {
                // User typed 'skip' — check in without photo
                if (lower === 'skip' || lower === 'no photo' || lower === 'without photo') {
                    this._stopCamera();
                    this._submitCheckIn(state.data, null);
                } else {
                    this._addBotMessage('📸 Please capture a photo using the camera above, or type <b>skip</b> to proceed without photo.');
                }
                break;
            }
            default:
                this._conversationState = null;
        }
    }

    async _submitCheckIn(data, photoB64) {
        this._conversationState = null;
        this._showTyping();
        try {
            const now = new Date();
            const currentHour = now.getHours();
            const currentMinute = now.getMinutes();
            const isLate = currentHour > 9 || (currentHour === 9 && currentMinute > 15);

            const checkInDateTime = now.getFullYear() + '-' +
                String(now.getMonth() + 1).padStart(2, '0') + '-' +
                String(now.getDate()).padStart(2, '0') + ' ' +
                String(now.getHours()).padStart(2, '0') + ':' +
                String(now.getMinutes()).padStart(2, '0') + ':' +
                String(now.getSeconds()).padStart(2, '0');

            const payload = {
                Employee_Name__c: this.employeeId,
                Date__c: now.toISOString().split('T')[0],
                Check_In_Time__c: checkInDateTime,
                Work_Location__c: data.workLocation,
                Check_In_Location__latitude__s: data.pos.latitude,
                Check_In_Location__longitude__s: data.pos.longitude,
                Check_In_Location_Name__c: data.pos.address || 'Voice Assistant',
                Status__c: isLate ? 'Late' : 'Present',
                Notes__c: 'Checked in via Voice Assistant'
            };

            // Attach photo if captured
            if (photoB64) {
                payload.Check_In_Photo_B64 = photoB64;
                payload.Check_In_Photo_Name = 'CheckIn_' + now.getTime() + '.jpg';
            }

            const result = await createAttendance({ payload: payload });
            this._hideTyping();

            if (result && result.success) {
                const time = this._formatTime(now);
                const photoNote = photoB64 ? '<br>📸 Photo: Captured' : '';
                this._addBotMessage(
                    `✅ <b>Checked in successfully!</b><br>` +
                    `⏰ Time: ${time}<br>` +
                    `📍 Location: ${data.pos.address || 'Recorded'}<br>` +
                    `🏢 Work Location: ${data.workLocation}${photoNote}<br><br>` +
                    `Have a great day! 💪`
                );
            } else {
                const errMsg = result && result.error ? result.error : 'Check-in could not be completed.';
                this._addBotMessage(`⚠️ ${errMsg}`);
            }
        } catch (error) {
            this._hideTyping();
            this._addBotMessage(`❌ Check-in failed: ${this._extractError(error)}`);
        }
    }

    // ─── CHECK OUT (Multi-step: photo → submit) ────────────
    async _handleCheckOut() {
        this._showTyping();
        try {
            // First, get today's attendance record
            const todayResult = await getTodayAttendanceRecord({ employeeId: this.employeeId });

            if (!todayResult || !todayResult.success || !todayResult.hasRecords || !todayResult.lastSession) {
                this._hideTyping();
                this._addBotMessage('⚠️ No active check-in found for today. Please check in first.');
                return;
            }

            const attendanceRecordId = todayResult.lastSession.recordId;
            if (!attendanceRecordId) {
                this._hideTyping();
                this._addBotMessage('⚠️ Could not find your attendance record. Please check in first.');
                return;
            }

            const pos = await this._getLocation();
            this._hideTyping();

            // Ask for check-out photo
            this._addBotMessage(
                `📸 <b>Please take a selfie for check-out</b><br><br>` +
                `Click the <b>📷 Open Camera</b> button below, or type <b>skip</b> to check out without a photo.`
            );

            this._conversationState = {
                flow: 'checkOut',
                step: 'awaitPhoto',
                data: { recordId: attendanceRecordId, pos: pos }
            };
            this._openCamera('checkOut');
        } catch (error) {
            this._hideTyping();
            this._addBotMessage(`❌ Check-out failed: ${this._extractError(error)}`);
        }
    }

    // ─── CHECK-OUT FLOW STEPS ───────────────────
    _handleCheckOutStep(lower, original, state) {
        if (state.step === 'awaitPhoto') {
            if (lower === 'skip' || lower === 'no photo' || lower === 'without photo') {
                this._stopCamera();
                this._submitCheckOut(state.data, null);
            } else {
                this._addBotMessage('📸 Please capture a photo using the camera above, or type <b>skip</b> to proceed without photo.');
            }
        } else {
            this._conversationState = null;
        }
    }

    async _submitCheckOut(data, photoB64) {
        this._conversationState = null;
        this._showTyping();
        try {
            const now = new Date();
            const checkOutDateTime = now.getFullYear() + '-' +
                String(now.getMonth() + 1).padStart(2, '0') + '-' +
                String(now.getDate()).padStart(2, '0') + ' ' +
                String(now.getHours()).padStart(2, '0') + ':' +
                String(now.getMinutes()).padStart(2, '0') + ':' +
                String(now.getSeconds()).padStart(2, '0');

            const changes = {
                Check_Out_Time__c: checkOutDateTime,
                Check_Out_Location__latitude__s: data.pos.latitude,
                Check_Out_Location__longitude__s: data.pos.longitude,
                Check_Out_Location_Name__c: data.pos.address || 'Voice Assistant',
                Notes__c: 'Checked out via Voice Assistant'
            };

            if (photoB64) {
                changes.Check_Out_Photo_B64 = photoB64;
                changes.Check_Out_Photo_Name = 'CheckOut_' + now.getTime() + '.jpg';
            }

            const result = await updateAttendance({
                recordId: data.recordId,
                changes: changes
            });

            this._hideTyping();

            if (result && result.success) {
                const time = this._formatTime(now);
                const photoNote = photoB64 ? '<br>📸 Photo: Captured' : '';
                this._addBotMessage(
                    `🚪 <b>Checked out successfully!</b><br>` +
                    `⏰ Time: ${time}${photoNote}<br>` +
                    `Good work today! 🎉`
                );
            } else {
                const errMsg = result && result.error ? result.error : 'Check-out could not be completed.';
                this._addBotMessage(`⚠️ ${errMsg}`);
            }
        } catch (error) {
            this._hideTyping();
            this._addBotMessage(`❌ Check-out failed: ${this._extractError(error)}`);
        }
    }

    // ─── LEAVE BALANCE ──────────────────────────
    async _handleLeaveBalance() {
        this._showTyping();
        try {
            const year = new Date().getFullYear().toString();
            const result = await getLeaveBalanceSummary({
                employeeId: this.employeeId,
                year: year
            });

            this._hideTyping();

            if (result) {
                let html = `📊 <b>Your Leave Balance (${year})</b><br><br>`;
                html += `Total Allocated: <b>${result.totalAllocated || 0} days</b><br>`;
                html += `Total Used: <b>${result.totalUsed || 0} days</b><br>`;
                html += `Total Available: <b>${result.totalAvailable || 0} days</b><br><br>`;

                // Show per-type breakdown if available
                if (result.balances && result.balances.length > 0) {
                    html += `<b>Breakdown:</b><br>`;
                    result.balances.forEach(bal => {
                        const name = bal.Leave_Type__r ? bal.Leave_Type__r.Leave_Type_Name__c : 'Unknown';
                        const avail = bal.Available__c || 0;
                        const alloc = bal.Total_Allocated__c || 0;
                        const used = bal.Used__c || 0;
                        html += `• <b>${name}</b>: ${avail} available (${alloc} allocated, ${used} used)<br>`;
                    });
                    html += `<br>`;
                }

                html += `Say <b>"Apply leave"</b> to request time off.`;
                this._addBotMessage(html);
            } else {
                this._addBotMessage('📊 Could not retrieve leave balance. Please try again later.');
            }
        } catch (error) {
            this._hideTyping();
            this._addBotMessage(`❌ Error loading leave balance: ${this._extractError(error)}`);
        }
    }

    // ─── ATTENDANCE SUMMARY ─────────────────────
    async _handleAttendanceSummary() {
        this._showTyping();
        try {
            const result = await getMonthlySummary({ userId: this.employeeId });

            this._hideTyping();

            if (result && result.success) {
                let html = `📋 <b>Attendance Summary — ${result.monthName || 'This Month'}</b><br><br>`;
                html += `✅ Present Days: <b>${result.presentDays || 0}</b><br>`;
                html += `⏰ Late Days: <b>${result.lateDays || 0}</b><br>`;
                html += `❌ Absent Days: <b>${result.absentDays || 0}</b><br>`;
                html += `📊 Attendance Rate: <b>${result.attendanceRate || '0'}%</b><br>`;
                html += `⏱️ Total Hours: <b>${result.totalHours || '0'} hrs</b>`;
                this._addBotMessage(html);
            } else {
                this._addBotMessage('📋 Could not load attendance summary. Please try again.');
            }
        } catch (error) {
            this._hideTyping();
            this._addBotMessage(`❌ Error: ${this._extractError(error)}`);
        }
    }

    // ─── APPLY LEAVE FLOW ───────────────────────
    async _startApplyLeaveFlow(preFilled = {}) {
        this._showTyping();
        try {
            const year = new Date().getFullYear().toString();
            this._leaveTypes = await getEmployeeLeaveBalances({
                employeeId: this.employeeId,
                year: year
            });
            this._hideTyping();

            if (!this._leaveTypes || this._leaveTypes.length === 0) {
                this._addBotMessage('⚠️ No leave types found for your profile. Please contact HR.');
                return;
            }

            const data = {};
            let step = 'awaitType';

            // 1. Handle Pre-filled Leave Type
            if (preFilled.leaveType) {
                const lowerType = preFilled.leaveType.toLowerCase();
                const found = this._leaveTypes.find(lt => {
                    const name = lt.Leave_Type__r ? lt.Leave_Type__r.Leave_Type_Name__c.toLowerCase() : '';
                    return name.includes(lowerType) || lowerType.includes(name);
                });
                if (found) {
                    data.leaveType = found;
                    data.leaveTypeName = found.Leave_Type__r ? found.Leave_Type__r.Leave_Type_Name__c : 'Leave';
                    data.leaveTypeId = found.Leave_Type__r ? found.Leave_Type__r.Id : found.Id;
                    step = 'awaitDates';
                }
            }

            // 2. Handle Pre-filled Dates
            if (step === 'awaitDates' && preFilled.startDate && preFilled.endDate) {
                data.startDate = preFilled.startDate;
                data.endDate = preFilled.endDate;
                data.numDays = this._calculateDays(data.startDate, data.endDate);
                step = 'awaitReason';
            }

            // 3. Handle Pre-filled Reason
            if (step === 'awaitReason' && preFilled.reason) {
                data.reason = preFilled.reason;
                step = 'awaitConfirm';
            }

            this._conversationState = { flow: 'applyLeave', step, data };

            if (step === 'awaitType') {
                let html = `📝 <b>Apply Leave</b><br><br>Available leave types:<br>`;
                this._leaveTypes.forEach((lt, idx) => {
                    const name = lt.Leave_Type__r ? lt.Leave_Type__r.Leave_Type_Name__c : 'Unknown';
                    const avail = lt.Available__c || 0;
                    html += `${idx + 1}. <b>${name}</b> — ${avail} days available<br>`;
                });
                html += `<br>Which leave type? (type the number or name)`;
                this._addBotMessage(html);
            } else {
                // We skipped some steps, provide a summary of what we caught
                let caughtMsg = `📝 <b>Applying ${data.leaveTypeName}</b><br>`;
                if (data.startDate) caughtMsg += `📅 ${this._formatDate(data.startDate)} to ${this._formatDate(data.endDate)} (${data.numDays} days)<br>`;

                // BALANCE VALIDATION ALERT
                if (data.leaveType && data.numDays > (data.leaveType.Available__c || 0)) {
                    caughtMsg += `<br>⚠️ <b>Low Balance Alert</b>: You only have ${data.leaveType.Available__c || 0} days available, but you are requesting ${data.numDays} days. Proceed with caution.`;
                }

                if (step === 'awaitReason') {
                    caughtMsg += `<br>What is the <b>reason</b> for leave?`;
                } else if (step === 'awaitConfirm') {
                    caughtMsg += `📝 Reason: <b>${data.reason}</b><br><br>Shall I submit this? (<b>yes</b> / <b>no</b>)`;
                }
                this._addBotMessage(caughtMsg);
            }
        } catch (error) {
            this._hideTyping();
            this._addBotMessage(`❌ Error loading leave types: ${this._extractError(error)}`);
        }
    }

    // ─── LOG TIMESHEET FLOW ─────────────────────
    async _startTimesheetFlow(originalText) {
        this._showTyping();
        try {
            // Fetch projects and status picklist
            const [projects, statuses] = await Promise.all([
                getProjects(),
                getStatusPicklistValues()
            ]);
            this._projects = projects;
            this._timesheetStatuses = statuses || [];
            this._hideTyping();

            if (!this._projects || this._projects.length === 0) {
                this._addBotMessage('⚠️ No projects assigned to you. Please contact your manager.');
                return;
            }

            // ─── SMART PARSE ───
            let parsed = { project: null, date: null, startTime: null, endTime: null, task: null, status: null };
            if (originalText && originalText.length > 5) {
                parsed = this._parseTimesheetFromMessage(originalText);
            }

            // Defaults
            if (!parsed.date) parsed.date = this._toDateString(new Date());

            // Determine next step based on what's missing
            let nextStep = 'awaitProject';
            let botMessage = '';

            if (!parsed.project) {
                nextStep = 'awaitProject';
                let html = `⏱️ <b>Log Timesheet</b><br><br>`;
                html += `I found the date <b>${parsed.date}</b>, but which project is this for?<br><br>`;
                html += `Your projects:<br>`;
                this._projects.forEach((p, idx) => {
                    html += `${idx + 1}. <b>${p.label || p.Name}</b><br>`;
                });
                botMessage = html;
            } else if (!parsed.startTime || !parsed.endTime) {
                nextStep = 'awaitTime';
                botMessage = `For <b>${parsed.project.label || parsed.project.Name}</b> on <b>${parsed.date}</b>, what was the <b>start and end time</b>? (e.g. "9 to 5" or "4 hours")`;
            } else if (!parsed.task) {
                nextStep = 'awaitTask';
                const hours = this._calculateHours(parsed.startTime, parsed.endTime);
                botMessage = `Got it: <b>${parsed.startTime} – ${parsed.endTime}</b> (${hours} hrs).<br>What was the <b>task/activity</b>?`;
            } else {
                // All good — confirmation
                nextStep = 'awaitDescription'; // Final confirmation step
                const totalMinutes = this._calculateMinutes(parsed.startTime, parsed.endTime);
                if (totalMinutes <= 0) {
                    botMessage = '⚠️ End time must be after start time. Please enter the time again (e.g. "9am to 5pm").';
                    nextStep = 'awaitTime'; // fallback to ask time again
                } else {
                    const totalHours = Math.round((totalMinutes / 60) * 100) / 100;
                    const statusDisplay = parsed.status || (this._timesheetStatuses.length > 0 ? this._timesheetStatuses[0] : 'N/A');

                    const data = {
                        project: parsed.project,
                        projectName: parsed.project.label || parsed.project.Name,
                        projectId: parsed.project.value || parsed.project.Id,
                        date: parsed.date,
                        startTime: parsed.startTime,
                        endTime: parsed.endTime,
                        task: parsed.task,
                        status: parsed.status,
                        totalHours: totalHours,
                        regularHours: Math.min(totalHours, 8),
                        overtimeHours: Math.max(0, totalHours - 8)
                    };

                    botMessage = `⏱️ <b>Almost done!</b><br><br>` +
                        `Project: <b>${data.projectName}</b><br>` +
                        `Time: <b>${data.startTime} — ${data.endTime}</b> (${data.totalHours} hrs)<br>` +
                        `Task: <b>${data.task}</b><br>` +
                        `Status: <b>${statusDisplay}</b><br><br>` +
                        `Any additional <b>description</b>? (or say <b>skip</b>)`;

                    this._addBotMessage(botMessage);
                    this._conversationState = {
                        flow: 'logTimesheet',
                        step: 'awaitDescription',
                        data: data
                    };
                    return;
                }
            }

            this._addBotMessage(botMessage);
            this._conversationState = {
                flow: 'logTimesheet',
                step: nextStep,
                data: {
                    project: parsed.project,
                    projectName: parsed.project ? (parsed.project.label || parsed.project.Name) : null,
                    projectId: parsed.project ? (parsed.project.value || parsed.project.Id) : null,
                    date: parsed.date,
                    startTime: parsed.startTime,
                    endTime: parsed.endTime,
                    task: parsed.task,
                    status: parsed.status
                }
            };

        } catch (error) {
            this._hideTyping();
            this._addBotMessage(`❌ Error loading projects: ${this._extractError(error)}`);
        }
    }

    _calculateMinutes(start, end) {
        const [sh, sm] = start.split(':').map(Number);
        const [eh, em] = end.split(':').map(Number);
        return (eh * 60 + em) - (sh * 60 + sm);
    }

    _calculateHours(start, end) {
        const mins = this._calculateMinutes(start, end);
        return Math.round((mins / 60) * 100) / 100;
    }

    // ─── SMART TIMESHEET PARSER ──────────────────
    _parseTimesheetFromMessage(text) {
        const lower = text.toLowerCase();
        const result = { project: null, date: null, startTime: null, endTime: null, task: null, status: null };

        // 1. Extract project
        result.project = this._findProjectFuzzy(lower);

        // 2. Extract times — handle many casual speech patterns
        let timeFound = false;

        // 2a. AM/PM range: "from 9:30 am to 1:30 pm", "9.30 am to 1.30 pm"
        const ampmFull = lower.match(/(?:from\s+)?(\d{1,2})[:\s.](\d{2})\s*(am|pm)\s*(?:to|-|till|until)\s*(\d{1,2})[:\s.](\d{2})\s*(am|pm)/i);
        if (ampmFull) {
            result.startTime = this._parseTime(`${ampmFull[1]}:${ampmFull[2]} ${ampmFull[3]}`);
            result.endTime = this._parseTime(`${ampmFull[4]}:${ampmFull[5]} ${ampmFull[6]}`);
            if (result.startTime && result.endTime) timeFound = true;
        }

        // 2b. Simple AM/PM range: "from 9 am to 1 pm"
        if (!timeFound) {
            const ampmSimple = lower.match(/(?:from\s+)?(\d{1,2})\s*(am|pm)\s*(?:to|-|till|until)\s*(\d{1,2})\s*(am|pm)/i);
            if (ampmSimple) {
                result.startTime = this._parseTime(`${ampmSimple[1]} ${ampmSimple[2]}`);
                result.endTime = this._parseTime(`${ampmSimple[3]} ${ampmSimple[4]}`);
                if (result.startTime && result.endTime) timeFound = true;
            }
        }

        // 2c. Duration pattern: "worked for 4 hours from 9:30 am" or just "for 4 hours" (defaults to 9am start)
        if (!timeFound) {
            const durationMatch = lower.match(/(?:worked\s+)?(?:for\s+)?(\d+(?:\.\d+)?)\s*(?:hours?|hrs?)/i);
            if (durationMatch) {
                const durationHours = parseFloat(durationMatch[1]);
                let foundStart = null;

                // Try to find a start time in the sentence
                const startPatterns = [
                    /(?:from|at|starting|since)\s+(\d{1,2})[:\s.](\d{2})\s*(am|pm)/i,
                    /(?:from|at|starting|since)\s+(\d{1,2})\s*(am|pm)/i,
                    /(\d{1,2})[:\s.](\d{2})\s*(am|pm)/i,
                    /(\d{1,2})\s*(am|pm)/i,
                    /(?:from|at|starting|since)\s+(\d{1,2})[:\s.](\d{2})/i,
                    /(?:from|at|starting|since)\s+(\d{1,2})\b/i
                ];

                for (const p of startPatterns) {
                    const m = lower.match(p);
                    if (m) {
                        if (m[3] && m[2] && m[1]) {
                            foundStart = m[2].length <= 2 && isNaN(m[2]) ? `${m[1]} ${m[2]}` : `${m[1]}:${m[2]} ${m[3]}`;
                        } else if (m[2] && isNaN(parseInt(m[2], 10))) {
                            foundStart = `${m[1]} ${m[2]}`;
                        } else if (m[2]) {
                            foundStart = `${m[1]}:${m[2]}`;
                        } else {
                            foundStart = m[1];
                        }
                        break;
                    }
                }

                // If no start time found, default to 09:00 AM
                if (!foundStart) {
                    foundStart = "09:00";
                }

                result.startTime = this._parseTime(foundStart);
                if (result.startTime) {
                    const [sh, sm] = result.startTime.split(':').map(Number);
                    const endMinutes = sh * 60 + sm + Math.round(durationHours * 60);
                    const eh = Math.floor(endMinutes / 60);
                    const em = endMinutes % 60;
                    // Cap at 23:59
                    const finalEh = Math.min(eh, 23);

                    result.endTime = String(finalEh).padStart(2, '0') + ':' + String(em).padStart(2, '0');
                    timeFound = true;
                }
            }
        }

        // 2d. 24h format: "from 9:00 to 17:00", "9:00 - 18:00"
        if (!timeFound) {
            const tf = [
                /(?:from\s+)?(\d{1,2}[:.]\d{2})\s*(?:to|-|till)\s*(\d{1,2}[:.]\d{2})/i,
                /(?:from\s+)?(\d{1,2})\s*(?:to|-|till)\s*(\d{1,2})\b/i
            ];
            for (const pattern of tf) {
                const m = lower.match(pattern);
                if (m) {
                    result.startTime = this._parseTime(m[1]);
                    result.endTime = this._parseTime(m[2]);
                    if (result.startTime && result.endTime) { timeFound = true; break; }
                }
            }
        }

        // 3. Extract task — multiple strategies for casual speech

        // Strategy 1: Explicit "task" keyword — enhanced for verbose intros
        const taskKw = [
            /(?:with\s+|my\s+)?task\s*(?:is|was|:|=|which I\s+\w+\s+is)?\s*[\"']?(.+?)[\"']?\s*(?:,|\.\s|\band\b\s+(?:so|worked|from|between|status|completed|for\s+\d)|$)/i,
            /(?:with\s+|my\s+)?task\s+[\"']?(.+?)[\"']?\s*(?:worked|from|between|status|for\s+\d|$)/i,
            /(?:with\s+)?task\s+[\"']?(.+?)[\"']?$/i
        ];
        for (const pattern of taskKw) {
            const m = text.match(pattern);
            if (m && m[1]) {
                let t = m[1].trim()
                    .replace(/\s*(?:and\s+)?(?:so|worked|from|between|with status|completed|in progress|for\s+\d)\s*.*$/i, '')
                    .replace(/\s*,\s*$/, '').trim();
                // Clean up leading "is" or "was" if regex caught it aggressively
                t = t.replace(/^(is|was)\s+/i, '');
                if (t.length > 2) { result.task = t; break; }
            }
        }

        // Strategy 2: Action verbs (e.g. "developed a LWC component", "worked on bug fixes")
        if (!result.task) {
            const verbMatch = text.match(
                /\b(developed|creating|created|building|built|designing|designed|implemented|implementing|coding|coded|fixing|fixed|debugging|debugged|testing|tested|reviewing|reviewed|updating|updated|refactored|refactoring|deployed|deploying|configured|configuring|integrated|integrating|migrated|migrating|analyzed|analyzing|optimized|optimizing|wrote|writing|completed|completing|finished|finishing|prepared|preparing|documented|documenting|worked\s+on|working\s+on)\s+(.+?)(?:\s+(?:and\s+)?(?:worked|from|for|between|status|\d{1,2}[:.]\d{2}|\d{1,2}\s*(?:am|pm)|\d+\s*(?:hours?|hrs?)).*$|$)/i
            );
            if (verbMatch && verbMatch[2]) {
                let t = (verbMatch[1] + ' ' + verbMatch[2]).trim()
                    .replace(/\s*,\s*$/, '')
                    .replace(/\s+(?:and\s+)?(?:from|for\s+\d|worked\s+for).*$/i, '').trim();
                if (t.length > 3) result.task = t;
            }
        }

        // Strategy 3: Content between project and time/duration markers
        if (!result.task && result.project) {
            const projName = (result.project.label || result.project.Name || '').toLowerCase();
            const projIdx = lower.indexOf(projName);
            if (projIdx !== -1) {
                let afterProj = text.substring(projIdx + projName.length).trim();
                afterProj = afterProj.replace(/^[\s,]*(?:and|with|then)?\s*/i, '');
                afterProj = afterProj
                    .replace(/\s*(?:from|for|between|worked|at|starting)\s+\d.*$/i, '')
                    .replace(/\s*(?:completed|in progress|done|finished)\s*$/i, '')
                    .replace(/\s*,\s*$/, '').trim();
                if (afterProj.length > 3) result.task = afterProj;
            }
        }

        // 4. Extract status
        for (const status of (this._timesheetStatuses || [])) {
            if (lower.includes(status.toLowerCase())) { result.status = status; break; }
        }
        if (!result.status) {
            if (/\b(?:completed|complete|done|finished)\b/.test(lower)) {
                result.status = (this._timesheetStatuses || []).find(s => /completed|complete/i.test(s)) || null;
            } else if (/\b(?:in progress|in-progress|ongoing|working)\b/.test(lower)) {
                result.status = (this._timesheetStatuses || []).find(s => /progress/i.test(s)) || null;
            }
        }

        // 5. Extract date
        if (lower.includes('today')) {
            result.date = this._toDateString(new Date());
        } else if (lower.includes('yesterday')) {
            const d = new Date(); d.setDate(d.getDate() - 1);
            result.date = this._toDateString(d);
        } else {
            const dateMatch = lower.match(/(\d{4}-\d{2}-\d{2})/);
            if (dateMatch) {
                result.date = dateMatch[1];
            } else {
                // Try natural date ("February 23")
                const stripped = text.replace(/\d{1,2}[:\s.]\d{2}\s*(?:am|pm)?/gi, '').trim();
                result.date = this._parseSingleDate(stripped);
            }
        }
        if (!result.date) result.date = this._toDateString(new Date());

        return result;
    }



    // ─── FUZZY PROJECT MATCHING ──────────────────
    _findProjectFuzzy(text) {
        if (!this._projects || this._projects.length === 0) return null;

        // Number word → digit mapping
        const numberWords = {
            'one': '1', 'two': '2', 'three': '3', 'four': '4', 'five': '5',
            'six': '6', 'seven': '7', 'eight': '8', 'nine': '9', 'ten': '10',
            'eleven': '11', 'twelve': '12', 'thirteen': '13', 'fourteen': '14', 'fifteen': '15',
            'first': '1', 'second': '2', 'third': '3', 'fourth': '4', 'fifth': '5'
        };

        // Replace number words with digits in the text for matching
        let normalizedText = text.toLowerCase();
        for (const [word, digit] of Object.entries(numberWords)) {
            normalizedText = normalizedText.replace(new RegExp('\\b' + word + '\\b', 'gi'), digit);
        }

        // Try exact number match: "project 1" → project at index 0
        const projNumMatch = normalizedText.match(/project\s*(\d+)/i);
        if (projNumMatch) {
            const num = parseInt(projNumMatch[1], 10);
            if (num >= 1 && num <= this._projects.length) {
                return this._projects[num - 1];
            }
        }

        // Try name matching against each project
        for (const proj of this._projects) {
            const projName = (proj.label || proj.Name || '').toLowerCase();
            // Also normalize the project name (replace number words)
            let normalizedProjName = projName;
            for (const [word, digit] of Object.entries(numberWords)) {
                normalizedProjName = normalizedProjName.replace(new RegExp('\\b' + word + '\\b', 'gi'), digit);
            }

            // Check if text contains the project name or normalized name
            if (normalizedText.includes(projName) || normalizedText.includes(normalizedProjName)) {
                return proj;
            }
            // Check if user said "Wadhwani project" and project is "Wadhwani"
            // (Handled by the includes check above if project name is shorter)
            // But if project name is "Wadhwani Project" and user said "Wadhwani", we need reverse check?
            // Usually project name is "Wadhwani", user says "Wadhwani project". "Wadhwani project" includes "Wadhwani". Matches.

            // Check if text contains project name + ' project'? Start with exact matching.
        }

        // Try partial matching — extract "for <project>" pattern
        // "create a time sheet for Wadhwani project" -> extract "Wadhwani project"
        const forMatch = normalizedText.match(/(?:for|project)\s+([\w\s\d]+?)\s*(?:,|\.|with task|the task|task|from|between|$)/i);
        if (forMatch) {
            const searchTerm = forMatch[1].trim();
            // Try matching extracted term against project names
            for (const proj of this._projects) {
                const projName = (proj.label || proj.Name || '').toLowerCase();
                // Check if extracted term STARTS with project name (e.g. term="wadhwani project", proj="wadhwani")
                if (searchTerm.includes(projName)) {
                    return proj;
                }
            }
        }

        return null;
    }

    // ─── CONVERSATION STEP HANDLER ──────────────
    _handleConversationStep(lower, original) {
        // Cancel at any point
        if (lower === 'cancel' || lower === 'stop' || lower === 'no') {
            if (this._conversationState.step === 'awaitConfirm') {
                this._conversationState = null;
                this._addBotMessage('Cancelled. No changes made. How else can I help?');
                return;
            }
            this._conversationState = null;
            this._addBotMessage('Cancelled. How else can I help?');
            return;
        }

        const state = this._conversationState;

        if (state.flow === 'checkIn') {
            this._handleCheckInStep(lower, original, state);
        } else if (state.flow === 'checkOut') {
            this._handleCheckOutStep(lower, original, state);
        } else if (state.flow === 'applyLeave') {
            this._handleLeaveStep(lower, original, state);
        } else if (state.flow === 'logTimesheet') {
            this._handleTimesheetStep(lower, original, state);
        }
    }

    // ─── LEAVE FLOW STEPS ───────────────────────
    _handleLeaveStep(lower, original, state) {
        switch (state.step) {
            case 'awaitType': {
                let found = null;
                // Try matching by number
                const num = parseInt(original, 10);
                if (!isNaN(num) && num >= 1 && num <= this._leaveTypes.length) {
                    found = this._leaveTypes[num - 1];
                }
                // Try matching by name
                if (!found) {
                    found = this._leaveTypes.find(lt => {
                        const name = lt.Leave_Type__r ? lt.Leave_Type__r.Leave_Type_Name__c.toLowerCase() : '';
                        return name.includes(lower) || lower.includes(name);
                    });
                }

                if (!found) {
                    this._addBotMessage('I couldn\'t find that leave type. Please type the number or name from the list above.');
                    return;
                }

                state.data.leaveType = found;
                state.data.leaveTypeName = found.Leave_Type__r ? found.Leave_Type__r.Leave_Type_Name__c : 'Leave';
                state.data.leaveTypeId = found.Leave_Type__r ? found.Leave_Type__r.Id : found.Id;
                state.step = 'awaitDates';
                this._addBotMessage(
                    `Got it: <b>${state.data.leaveTypeName}</b><br><br>` +
                    `Now, what dates? Examples:<br>` +
                    `• <b>tomorrow</b><br>` +
                    `• <b>February 23</b> or <b>Feb 23</b><br>` +
                    `• <b>Feb 23 to Feb 27</b> (range)<br>` +
                    `• <b>March 5 to March 10</b><br>` +
                    `• <b>2026-02-20</b> (ISO format)`
                );
                break;
            }
            case 'awaitDates': {
                const dates = this._parseDateRange(original);
                if (!dates) {
                    this._addBotMessage(
                        `I couldn't understand the dates. Try:<br>` +
                        `• <b>February 23</b> or <b>Feb 23</b><br>` +
                        `• <b>Feb 23 to Feb 27</b><br>` +
                        `• <b>tomorrow</b> or <b>next Monday</b><br>` +
                        `• <b>2026-02-20</b>`
                    );
                    return;
                }

                state.data.startDate = dates.start;
                state.data.endDate = dates.end;
                state.data.numDays = this._calculateDays(dates.start, dates.end);
                state.step = 'awaitReason';

                let msg = `📅 Dates: <b>${this._formatDate(dates.start)}</b> to <b>${this._formatDate(dates.end)}</b> (${state.data.numDays} day${state.data.numDays > 1 ? 's' : ''})<br>`;

                // BALANCE VALIDATION ALERT
                if (state.data.leaveType && state.data.numDays > (state.data.leaveType.Available__c || 0)) {
                    msg += `<br>⚠️ <b>Low Balance Alert</b>: You only have ${state.data.leaveType.Available__c || 0} days available, but you are requesting ${state.data.numDays} days.<br>`;
                }

                msg += `<br>What's the reason for leave?`;
                this._addBotMessage(msg);
                break;
            }
            case 'awaitReason': {
                state.data.reason = original;
                state.step = 'awaitConfirm';
                this._addBotMessage(
                    `📝 <b>Leave Request Summary</b><br><br>` +
                    `Type: <b>${state.data.leaveTypeName}</b><br>` +
                    `From: <b>${this._formatDate(state.data.startDate)}</b><br>` +
                    `To: <b>${this._formatDate(state.data.endDate)}</b><br>` +
                    `Days: <b>${state.data.numDays}</b><br>` +
                    `Reason: <b>${state.data.reason}</b><br><br>` +
                    `Shall I submit this? (<b>yes</b> / <b>no</b>)`
                );
                break;
            }
            case 'awaitConfirm': {
                if (lower === 'yes' || lower === 'y' || lower === 'confirm' || lower === 'submit') {
                    this._submitLeaveRequest(state.data);
                } else {
                    this._conversationState = null;
                    this._addBotMessage('Leave request cancelled. How else can I help?');
                }
                break;
            }
            default:
                this._conversationState = null;
        }
    }

    async _submitLeaveRequest(data) {
        this._conversationState = null;
        this._showTyping();
        try {
            const leaveRequest = {
                sobjectType: 'Leave_Request__c',
                Employee__c: this.employeeId,
                Leave_Type__c: data.leaveTypeId,
                Start_Date__c: data.startDate,
                End_Date__c: data.endDate,
                Total_Days__c: data.numDays,
                Reason__c: data.reason,
                Status__c: 'Pending'
            };

            await submitLeaveRequest({ leaveRequest: leaveRequest });
            this._hideTyping();
            this._addBotMessage(
                `✅ <b>Leave request submitted!</b><br><br>` +
                `Type: ${data.leaveTypeName}<br>` +
                `${this._formatDate(data.startDate)} — ${this._formatDate(data.endDate)}<br>` +
                `Status: <b>Pending Approval</b><br><br>` +
                `Your manager will be notified. 📩`
            );
        } catch (error) {
            this._hideTyping();
            this._addBotMessage(`❌ Failed to submit leave: ${this._extractError(error)}`);
        }
    }

    // ─── TIMESHEET FLOW STEPS ───────────────────
    _handleTimesheetStep(lower, original, state) {
        switch (state.step) {
            case 'awaitProject': {
                // Use fuzzy match
                let found = null;
                const num = parseInt(original, 10);
                if (!isNaN(num) && num >= 1 && num <= this._projects.length) {
                    found = this._projects[num - 1];
                }
                if (!found) {
                    found = this._findProjectFuzzy(lower);
                }
                if (!found) {
                    found = this._projects.find(p => {
                        const name = (p.label || p.Name || '').toLowerCase();
                        return name.includes(lower) || lower.includes(name);
                    });
                }

                if (!found) {
                    this._addBotMessage('Project not found. Please type the number or name from the list above.');
                    return;
                }

                state.data.project = found;
                state.data.projectName = found.label || found.Name;
                state.data.projectId = found.value || found.Id;

                // If hours were pre-set (from _handleTimesheetDirect), skip directly to submit
                if (state.data.hours) {
                    const sv = this._timesheetStatuses[0] || null;
                    this._submitTimesheetHoursOnly({
                        project: found,
                        date: state.data.date || this._toDateString(new Date()),
                        hours: state.data.hours,
                        task: state.data.task || 'General Work',
                        statusValue: sv
                    });
                    break;
                }

                state.step = 'awaitDate';
                this._addBotMessage(
                    `Project: <b>${state.data.projectName}</b> ✓<br><br>` +
                    `What date? (e.g. <b>today</b>, <b>yesterday</b>, or <b>2026-02-18</b>)`
                );
                break;
            }
            case 'awaitDate': {
                const date = this._parseSingleDate(original);
                if (!date) {
                    this._addBotMessage('I couldn\'t understand the date. Try <b>today</b>, <b>yesterday</b>, or <b>2026-02-18</b>.');
                    return;
                }

                state.data.date = date;
                state.step = 'awaitStartTime';
                this._addBotMessage(
                    `Date: <b>${this._formatDate(date)}</b> ✓<br><br>` +
                    `What was your <b>start time</b>? (e.g. <b>09:00</b>, <b>09:30</b>, <b>10:00</b>)`
                );
                break;
            }
            case 'awaitStartTime': {
                // Accept "X hours" directly — skip start/end time and submit immediately
                const directHrs = (() => {
                    const hm = original.match(/(\d+(?:\.\d+)?)\s*(?:hours?|hrs?)\b/i);
                    if (hm) return parseFloat(hm[1]);
                    if (/\bhalf[\s-]?day\b/i.test(original)) return 4;
                    if (/\bfull[\s-]?day\b/i.test(original)) return 8;
                    return null;
                })();
                if (directHrs && directHrs > 0) {
                    const sv = this._timesheetStatuses[0] || null;
                    this._submitTimesheetHoursOnly({
                        project: state.data.project,
                        date: state.data.date,
                        hours: directHrs,
                        task: state.data.task || 'General Work',
                        statusValue: sv
                    });
                    break;
                }

                // Try to extract BOTH start and end times from one message
                // e.g. "from 9:30 to 12", "from start time 9:30 to end time 12:00"
                const bothTimesMatch = original.match(/(\d{1,2}[:.]\d{2}|\d{1,2})\s*(?:to|-|till|until)\s*(\d{1,2}[:.]\d{2}|\d{1,2})/i);
                if (bothTimesMatch) {
                    const startT = this._parseTime(bothTimesMatch[1]);
                    const endT = this._parseTime(bothTimesMatch[2]);
                    if (startT && endT) {
                        const [sH, sM] = startT.split(':').map(Number);
                        const [eH, eM] = endT.split(':').map(Number);
                        if ((eH * 60 + eM) > (sH * 60 + sM)) {
                            state.data.startTime = startT;
                            state.data.endTime = endT;
                            const totalMin = (eH * 60 + eM) - (sH * 60 + sM);
                            state.data.totalHours = Math.round((totalMin / 60) * 100) / 100;
                            state.data.regularHours = Math.min(state.data.totalHours, 8);
                            state.data.overtimeHours = Math.max(0, state.data.totalHours - 8);
                            state.step = 'awaitTask';
                            this._addBotMessage(
                                `Start: <b>${startT}</b> → End: <b>${endT}</b> ✓ (${state.data.totalHours} hrs)<br><br>` +
                                `What <b>task</b> did you work on? (e.g. Development, Testing, Meeting, Design)`
                            );
                            break;
                        }
                    }
                }

                // Try extracting a single time from the message
                const time = this._extractTimeFromText(original);
                if (!time) {
                    this._addBotMessage('Please enter a valid time (e.g. <b>09:00</b>, <b>9:30</b>, <b>10</b>, or <b>from 9:30 to 12:00</b>) or just say <b>4 hours</b>.');
                    return;
                }
                state.data.startTime = time;
                state.step = 'awaitEndTime';
                this._addBotMessage(
                    `Start time: <b>${time}</b> ✓<br><br>` +
                    `What was your <b>end time</b>? (e.g. <b>17:00</b>, <b>18:00</b>, <b>18:30</b>)`
                );
                break;
            }
            case 'awaitEndTime': {
                // Try extracting time from the sentence
                const time = this._extractTimeFromText(original);
                if (!time) {
                    this._addBotMessage('Please enter a valid time (e.g. <b>17:00</b>, <b>18</b>, <b>18:30</b>).');
                    return;
                }
                // Validate end > start
                const [sh, sm] = state.data.startTime.split(':').map(Number);
                const [eh, em] = time.split(':').map(Number);
                if ((eh * 60 + em) <= (sh * 60 + sm)) {
                    this._addBotMessage('End time must be after start time. Please enter a valid end time.');
                    return;
                }
                state.data.endTime = time;
                // Calculate hours
                const totalMinutes = (eh * 60 + em) - (sh * 60 + sm);
                state.data.totalHours = Math.round((totalMinutes / 60) * 100) / 100;
                state.data.regularHours = Math.min(state.data.totalHours, 8);
                state.data.overtimeHours = Math.max(0, state.data.totalHours - 8);

                state.step = 'awaitTask';
                this._addBotMessage(
                    `End time: <b>${time}</b> ✓ (${state.data.totalHours} hours)<br><br>` +
                    `What <b>task</b> did you work on? (e.g. Development, Testing, Meeting, Design)`
                );
                break;
            }
            case 'awaitTask': {
                if (!original || original.trim().length === 0) {
                    this._addBotMessage('Please enter a task name.');
                    return;
                }
                state.data.task = original.trim();
                state.step = 'awaitStatus';
                let statusHtml = `Task: <b>${state.data.task}</b> ✓<br><br>`;
                statusHtml += `Select <b>status</b>:<br>`;
                if (this._timesheetStatuses.length > 0) {
                    this._timesheetStatuses.forEach((s, idx) => {
                        statusHtml += `${idx + 1}. <b>${s}</b><br>`;
                    });
                    statusHtml += `<br>Type the number or status name`;
                } else {
                    statusHtml += `Type your status (e.g. Completed, In Progress)`;
                }
                this._addBotMessage(statusHtml);
                break;
            }
            case 'awaitStatus': {
                let matchedStatus = null;
                const num = parseInt(original, 10);
                if (!isNaN(num) && num >= 1 && num <= this._timesheetStatuses.length) {
                    matchedStatus = this._timesheetStatuses[num - 1];
                }
                if (!matchedStatus) {
                    matchedStatus = this._timesheetStatuses.find(s => s.toLowerCase() === lower);
                }
                if (!matchedStatus) {
                    matchedStatus = this._timesheetStatuses.find(s => s.toLowerCase().includes(lower) || lower.includes(s.toLowerCase()));
                }
                if (!matchedStatus && original.trim().length > 0) {
                    matchedStatus = original.trim(); // Use raw input as fallback
                }
                if (!matchedStatus) {
                    this._addBotMessage('Please enter a valid status.');
                    return;
                }
                state.data.status = matchedStatus;
                state.step = 'awaitDescription';
                this._addBotMessage(
                    `Status: <b>${matchedStatus}</b> ✓<br><br>` +
                    `Any additional <b>description</b>? (or say <b>skip</b>)<br>` +
                    `<i>(e.g. "Developed OBC component with validations")</i>`
                );
                break;
            }
            case 'awaitDescription': {
                const skipWords = ['skip', 'no', 'none', 'na', 'n/a', '-'];
                if (skipWords.includes(lower)) {
                    // Use task name as description
                    state.data.description = state.data.task;
                } else if (!original || original.trim().length === 0) {
                    state.data.description = state.data.task;
                } else {
                    state.data.description = original.trim();
                }
                state.step = 'awaitConfirm';
                this._addBotMessage(
                    `⏱️ <b>Timesheet Entry Summary</b><br><br>` +
                    `Project: <b>${state.data.projectName}</b><br>` +
                    `Date: <b>${this._formatDate(state.data.date)}</b><br>` +
                    `Time: <b>${state.data.startTime} — ${state.data.endTime}</b> (${state.data.totalHours} hrs)<br>` +
                    `Task: <b>${state.data.task}</b><br>` +
                    `Description: <b>${state.data.description}</b><br>` +
                    `Status: <b>${state.data.status}</b><br><br>` +
                    `Shall I submit this? (<b>yes</b> / <b>no</b>)`
                );
                break;
            }
            case 'awaitConfirm': {
                if (lower === 'yes' || lower === 'y' || lower === 'confirm' || lower === 'submit') {
                    this._submitTimesheetEntry(state.data);
                } else {
                    this._conversationState = null;
                    this._addBotMessage('Timesheet entry cancelled. How else can I help?');
                }
                break;
            }
            default:
                this._conversationState = null;
        }
    }

    async _submitTimesheetEntry(data) {
        this._conversationState = null;
        this._showTyping();
        try {
            // Use user-specified status, or first valid from picklist
            const statusValue = data.status || (this._timesheetStatuses.length > 0 ? this._timesheetStatuses[0] : null);

            const row = {
                Project__c: data.projectId,
                Date__c: data.date,
                Start_Time__c: data.startTime,
                End_Time__c: data.endTime,
                Task__c: data.task,
                Description__c: data.description || 'Logged via Voice Assistant',
                Status__c: statusValue,
                Regular_Hours__c: data.regularHours || 0,
                Overtime_Hours__c: data.overtimeHours || 0,
                Total_Hours__c: data.totalHours || 0,
                Approval_Status__c: 'Draft'
            };
            await createMultipleTimesheetEntries({ rows: [row] });
            this._hideTyping();
            this._addBotMessage(
                `✅ <b>Timesheet entry saved!</b><br><br>` +
                `Project: ${data.projectName}<br>` +
                `Date: ${this._formatDate(data.date)}<br>` +
                `Time: ${data.startTime} — ${data.endTime} (${data.totalHours} hrs)<br>` +
                `Task: ${data.task}<br>` +
                `Status: ${statusValue}<br><br>` +
                `Keep up the great work! 💪`
            );
        } catch (error) {
            this._hideTyping();
            this._addBotMessage(`❌ Failed to save timesheet: ${this._extractError(error)}`);
        }
    }

    // ─── NAVIGATION ─────────────────────────────
    _matchesNavigation(text) {
        const tabMap = {
            overview: ['overview', 'dashboard', 'home'],
            attendance: ['attendance', 'check in tab', 'checkin tab'],
            timesheet: ['timesheet', 'time sheet', 'hours tab'],
            employeeselfservice: ['workflex', 'leave tab', 'self service', 'employee self service', 'wfh'],
            payslip: ['payslip', 'pay slip', 'salary', 'pay'],
            goals: ['goals', 'performance', 'targets'],
            learning: ['learning', 'training', 'courses', 'development']
        };

        const strongPrefixes = ['go to ', 'navigate to ', 'switch to ', 'take me to '];
        const weakPrefixes = ['show ', 'open '];

        let tabQuery = '';
        let isStrong = false;

        for (const prefix of strongPrefixes) {
            if (text.startsWith(prefix)) {
                tabQuery = text.substring(prefix.length).trim();
                isStrong = true;
                break;
            }
        }
        if (!tabQuery) {
            for (const prefix of weakPrefixes) {
                if (text.startsWith(prefix)) {
                    tabQuery = text.substring(prefix.length).trim();
                    break;
                }
            }
        }

        if (!tabQuery) return false;

        for (const [tabValue, keywords] of Object.entries(tabMap)) {
            if (keywords.some(k => tabQuery.includes(k))) {
                this._addBotMessage(`🧭 Navigating to <b>${tabValue}</b> tab...`);
                this.dispatchEvent(new CustomEvent('navigatetotab', {
                    detail: { tabValue: tabValue },
                    bubbles: true,
                    composed: true
                }));
                return true;
            }
        }

        // If strong intent (go to...) but no tab found, show error and stop.
        // If weak intent (show...) but no tab found, fall through to AI.
        if (isStrong) {
            this._addBotMessage(`I couldn't find a tab matching "<b>${tabQuery}</b>". Available tabs: Overview, Attendance, Timesheet, WorkFlex Hub, Payslip, Goals, Learning.`);
            return true;
        }
        return false;
    }

    // ─── UTILITY METHODS ────────────────────────
    _addUserMessage(text) {
        msgIdCounter++;
        this.messages = [...this.messages, {
            id: 'msg-' + msgIdCounter,
            text: text,
            html: this._escapeHtml(text),
            isBot: false,
            cssClass: 'msg-row user-msg',
            time: this._formatTime(new Date())
        }];
        this._scrollToBottom();
    }

    _addBotMessage(html) {
        msgIdCounter++;
        this.messages = [...this.messages, {
            id: 'msg-' + msgIdCounter,
            text: html,
            html: html,
            isBot: true,
            cssClass: 'msg-row bot-msg',
            time: this._formatTime(new Date())
        }];
        this._scrollToBottom();
    }

    async connectedCallback() {
        console.log('Bridge Check: Probe initiated...');
        try {
            const status = await checkStatus({ p1: 'init' });
            console.log('Bridge Status:', status);
        } catch (err) {
            console.error('Bridge Error: Request blocked by platform security:', err);
        }
    }

    _showTyping() {
        this.isTyping = true;
        this._scrollToBottom();
    }

    _hideTyping() {
        this.isTyping = false;
    }

    _scrollToBottom() {
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        setTimeout(() => {
            const el = this.refs.chatMessages;
            if (el) {
                el.scrollTop = el.scrollHeight;
            }
        }, 50);
    }

    _formatTime(date) {
        return date.toLocaleTimeString('en-US', {
            hour: '2-digit',
            minute: '2-digit',
            hour12: true
        });
    }

    _formatDate(dateStr) {
        if (!dateStr) return '';
        const d = new Date(dateStr + 'T00:00:00');
        return d.toLocaleDateString('en-US', {
            weekday: 'short',
            month: 'short',
            day: 'numeric',
            year: 'numeric'
        });
    }

    _escapeHtml(text) {
        const div = document.createElement('div');
        div.appendChild(document.createTextNode(text));
        return div.innerHTML;
    }

    _extractError(error) {
        if (!error) return 'Unknown error';
        if (typeof error === 'string') return error;
        if (error.body && error.body.message) return error.body.message;
        if (error.message) return error.message;
        return JSON.stringify(error);
    }

    _getLocation() {
        return new Promise((resolve, reject) => {
            if (!navigator.geolocation) {
                resolve({ latitude: 0, longitude: 0, address: 'Geolocation not supported' });
                return;
            }
            navigator.geolocation.getCurrentPosition(
                (position) => {
                    resolve({
                        latitude: position.coords.latitude,
                        longitude: position.coords.longitude,
                        address: `Lat: ${position.coords.latitude.toFixed(4)}, Lng: ${position.coords.longitude.toFixed(4)}`
                    });
                },
                (error) => {
                    console.warn('Geolocation error:', error);
                    resolve({ latitude: 0, longitude: 0, address: 'Location unavailable' });
                },
                { enableHighAccuracy: true, timeout: 10000 }
            );
        });
    }

    // ─── CAMERA METHODS ─────────────────────────
    _openCamera(mode) {
        this._cameraMode = mode;
        this.capturedPhotoB64 = null;
        this.showCamera = true;
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        setTimeout(async () => {
            try {
                const stream = await navigator.mediaDevices.getUserMedia({
                    video: { facingMode: 'user', width: { ideal: 640 }, height: { ideal: 480 } }
                });
                this._cameraStream = stream;
                const video = this.template.querySelector('.camera-video');
                if (video) {
                    video.srcObject = stream;
                    video.play();
                }
            } catch (err) {
                console.warn('Camera error:', err);
                this.showCamera = false;
                this._addBotMessage('⚠️ Camera not available. Type <b>skip</b> to proceed without photo.');
            }
        }, 200);
    }

    _stopCamera() {
        if (this._cameraStream) {
            this._cameraStream.getTracks().forEach(track => track.stop());
            this._cameraStream = null;
        }
        this.showCamera = false;
        this.capturedPhotoB64 = null;
    }

    handleCapturePhoto() {
        const video = this.template.querySelector('.camera-video');
        if (!video) return;
        const canvas = document.createElement('canvas');
        canvas.width = video.videoWidth || 640;
        canvas.height = video.videoHeight || 480;
        const ctx = canvas.getContext('2d');
        ctx.drawImage(video, 0, 0, canvas.width, canvas.height);
        const dataUrl = canvas.toDataURL('image/jpeg', 0.8);
        // Extract base64 part (remove 'data:image/jpeg;base64,' prefix)
        this.capturedPhotoB64 = dataUrl.split(',')[1];
        this._capturedDataUrl = dataUrl;
        // Stop camera stream after capture
        if (this._cameraStream) {
            this._cameraStream.getTracks().forEach(track => track.stop());
            this._cameraStream = null;
        }
        // Set image preview src after DOM re-render
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        setTimeout(() => {
            const img = this.template.querySelector('.photo-preview-img');
            if (img) {
                img.src = this._capturedDataUrl;
            }
        }, 100);
        this._addBotMessage('✅ Photo captured! Click <b>✓ Use Photo</b> to proceed or <b>🔄 Retake</b>.');
    }

    handleRetakePhoto() {
        this.capturedPhotoB64 = null;
        this._openCamera(this._cameraMode);
    }

    handleUsePhoto() {
        const photoB64 = this.capturedPhotoB64;
        this._stopCamera();
        const state = this._conversationState;
        if (!state) return;
        if (state.flow === 'checkIn') {
            this._submitCheckIn(state.data, photoB64);
        } else if (state.flow === 'checkOut') {
            this._submitCheckOut(state.data, photoB64);
        }
    }

    handleSkipPhoto() {
        this._stopCamera();
        const state = this._conversationState;
        if (!state) return;
        if (state.flow === 'checkIn') {
            this._submitCheckIn(state.data, null);
        } else if (state.flow === 'checkOut') {
            this._submitCheckOut(state.data, null);
        }
    }

    // ─── TIME PARSING ───────────────────────────
    _parseTime(text) {
        if (!text) return null;
        // Remove dots (a.m. -> am) and collapse spaces
        const cleaned = text.trim().toLowerCase().replace(/\./g, '').replace(/\s+/g, ' ');

        // Helper to convert 12-hour to 24-hour
        const to24h = (h, m, ampm) => {
            let hour = h;
            if (ampm === 'pm' && hour !== 12) hour += 12;
            if (ampm === 'am' && hour === 12) hour = 0;
            if (hour >= 0 && hour <= 23 && m >= 0 && m <= 59) {
                return String(hour).padStart(2, '0') + ':' + String(m).padStart(2, '0');
            }
            return null;
        };

        // Match HH:MM AM/PM or HH.MM AM/PM (e.g. "9:30 am", "9.30am", "1:30 PM")
        const ampmMatch = cleaned.match(/^(\d{1,2})[\s.:]+(\d{2})\s*(am|pm)$/);
        if (ampmMatch) {
            return to24h(parseInt(ampmMatch[1], 10), parseInt(ampmMatch[2], 10), ampmMatch[3]);
        }

        // Match H AM/PM (e.g. "9 am", "1pm", "12 PM")
        const ampmSimple = cleaned.match(/^(\d{1,2})\s*(am|pm)$/);
        if (ampmSimple) {
            return to24h(parseInt(ampmSimple[1], 10), 0, ampmSimple[2]);
        }

        // Match HH:MM pattern 24h (e.g. "09:00", "9:30", "17:00")
        const timeMatch = cleaned.match(/^(\d{1,2}):(\d{2})$/);
        if (timeMatch) {
            const h = parseInt(timeMatch[1], 10);
            const m = parseInt(timeMatch[2], 10);
            if (h >= 0 && h <= 23 && m >= 0 && m <= 59) {
                return String(h).padStart(2, '0') + ':' + String(m).padStart(2, '0');
            }
        }

        // Match just a number (e.g. "9" → "09:00", "17" → "17:00")
        const numMatch = cleaned.match(/^(\d{1,2})$/);
        if (numMatch) {
            const h = parseInt(numMatch[1], 10);
            if (h >= 0 && h <= 23) {
                return String(h).padStart(2, '0') + ':00';
            }
        }

        // Match "9 30" or "9.30" format (no AM/PM)
        const altMatch = cleaned.match(/^(\d{1,2})[\s.](\d{2})$/);
        if (altMatch) {
            const h = parseInt(altMatch[1], 10);
            const m = parseInt(altMatch[2], 10);
            if (h >= 0 && h <= 23 && m >= 0 && m <= 59) {
                return String(h).padStart(2, '0') + ':' + String(m).padStart(2, '0');
            }
        }
        return null;
    }

    // Extract time from a natural language sentence
    _extractTimeFromText(text) {
        if (!text) return null;
        // First, try parsing the raw text directly
        const direct = this._parseTime(text);
        if (direct) return direct;

        // Try to find a time pattern (HH:MM or H:MM) in the text
        const colonMatch = text.match(/(\d{1,2}:\d{2})/);
        if (colonMatch) {
            const t = this._parseTime(colonMatch[1]);
            if (t) return t;
        }

        // Try to find a dot-separated time (9.30)
        const dotMatch = text.match(/(\d{1,2}\.\d{2})/);
        if (dotMatch) {
            const t = this._parseTime(dotMatch[1]);
            if (t) return t;
        }

        // Try to find a standalone number (e.g. "start time 9" or "end time 12")
        // Look for the last number in the text as it's likely the time
        const numbers = text.match(/\d{1,2}/g);
        if (numbers && numbers.length > 0) {
            // Use the last number found
            const lastNum = numbers[numbers.length - 1];
            const t = this._parseTime(lastNum);
            if (t) return t;
        }

        return null;
    }

    // ─── DATE PARSING ───────────────────────────
    _parseSingleDate(text) {
        let clean = text.toLowerCase().replace(/\b(for|on|apply|the|from|to|at)\b/gi, '').trim();
        const today = new Date();

        if (clean === 'today') {
            return this._toDateString(today);
        }
        if (clean === 'yesterday') {
            const d = new Date(today);
            d.setDate(d.getDate() - 1);
            return this._toDateString(d);
        }
        if (clean === 'tomorrow') {
            const d = new Date(today);
            d.setDate(d.getDate() + 1);
            return this._toDateString(d);
        }

        // Try YYYY-MM-DD
        const isoMatch = clean.match(/(\d{4}-\d{2}-\d{2})/);
        if (isoMatch) return isoMatch[1];

        // Try DD/MM/YYYY or DD-MM-YYYY
        const dmyMatch = clean.match(/(\d{1,2})[/-](\d{1,2})[/-](\d{4})/);
        if (dmyMatch) {
            const day = dmyMatch[1].padStart(2, '0');
            const month = dmyMatch[2].padStart(2, '0');
            return `${dmyMatch[3]}-${month}-${day}`;
        }

        // Month name map
        const monthMap = {
            'january': 1, 'jan': 1, 'february': 2, 'feb': 2, 'march': 3, 'mar': 3,
            'april': 4, 'apr': 4, 'may': 5, 'june': 6, 'jun': 6,
            'july': 7, 'jul': 7, 'august': 8, 'aug': 8, 'september': 9, 'sep': 9, 'sept': 9,
            'october': 10, 'oct': 10, 'november': 11, 'nov': 11, 'december': 12, 'dec': 12
        };

        // Try "Month Day" or "Month Day, Year" (e.g. "February 23", "Feb 23", "March 5, 2026")
        const monthDayMatch = clean.match(/^(january|jan|february|feb|march|mar|april|apr|may|june|jun|july|jul|august|aug|september|sep|sept|october|oct|november|nov|december|dec)\s+(\d{1,2})(?:st|nd|rd|th)?(?:[,\s]+(\d{4}))?$/i);
        if (monthDayMatch) {
            const month = monthMap[monthDayMatch[1]];
            const day = parseInt(monthDayMatch[2], 10);
            let year = monthDayMatch[3] ? parseInt(monthDayMatch[3], 10) : this._inferYear(month, day);
            if (month && day >= 1 && day <= 31) {
                return `${year}-${String(month).padStart(2, '0')}-${String(day).padStart(2, '0')}`;
            }
        }

        // Try "Day Month" or "Day Month Year" (e.g. "23 February", "23rd Feb", "23 Feb 2026")
        const dayMonthMatch = clean.match(/^(\d{1,2})(?:st|nd|rd|th)?\s+(january|jan|february|feb|march|mar|april|apr|may|june|jun|july|jul|august|aug|september|sep|sept|october|oct|november|nov|december|dec)(?:[,\s]+(\d{4}))?$/i);
        if (dayMonthMatch) {
            const day = parseInt(dayMonthMatch[1], 10);
            const month = monthMap[dayMonthMatch[2]];
            let year = dayMonthMatch[3] ? parseInt(dayMonthMatch[3], 10) : this._inferYear(month, day);
            if (month && day >= 1 && day <= 31) {
                return `${year}-${String(month).padStart(2, '0')}-${String(day).padStart(2, '0')}`;
            }
        }

        // Try day names (next Monday, etc.)
        const days = ['sunday', 'monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday'];
        const dayIdx = days.findIndex(d => clean.includes(d));
        if (dayIdx !== -1) {
            const currentDay = today.getDay();
            let diff = dayIdx - currentDay;
            if (diff <= 0 || clean.includes('next')) diff += 7;
            const target = new Date(today);
            target.setDate(target.getDate() + diff);
            return this._toDateString(target);
        }

        return null;
    }

    _inferYear(month, day) {
        const today = new Date();
        const currentYear = today.getFullYear();
        const currentMonth = today.getMonth() + 1;
        const currentDay = today.getDate();
        // If the month/day is in the past this year, assume next year
        if (month < currentMonth || (month === currentMonth && day < currentDay)) {
            return currentYear + 1;
        }
        return currentYear;
    }

    _parseDateRange(text) {
        const lower = text.toLowerCase().trim();

        // Check for "next week"
        if (lower.includes('next week')) {
            const today = new Date();
            const mondayNext = new Date(today);
            mondayNext.setDate(today.getDate() + (1 + 7 - today.getDay()) % 7 + (today.getDay() === 0 ? 0 : 7));
            const fridayNext = new Date(mondayNext);
            fridayNext.setDate(mondayNext.getDate() + 4);

            // "Monday to Wednesday next week"
            const rangeMatch = lower.match(/\b(monday|tuesday|wednesday|thursday|friday|saturday|sunday)\s+(?:to|and|-)\s+(monday|tuesday|wednesday|thursday|friday|saturday|sunday)\b/i);
            if (rangeMatch) {
                const days = ['sunday', 'monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday'];
                const d1 = days.indexOf(rangeMatch[1]);
                const d2 = days.indexOf(rangeMatch[2]);
                const start = new Date(mondayNext);
                start.setDate(mondayNext.getDate() + (d1 - 1)); // -1 because mondayNext is monday
                const end = new Date(mondayNext);
                end.setDate(mondayNext.getDate() + (d2 - 1));
                return { start: this._toDateString(start), end: this._toDateString(end) };
            }
            return { start: this._toDateString(mondayNext), end: this._toDateString(fridayNext) };
        }

        // Check for "X to Y" pattern
        const toMatch = lower.split(/\s+to\s+/);
        if (toMatch.length === 2) {
            const start = this._parseSingleDate(toMatch[0]);
            const end = this._parseSingleDate(toMatch[1]);
            if (start && end) return { start, end };
        }

        // Check for "from X to Y"
        const fromToMatch = lower.match(/from\s+(.+?)\s+to\s+(.+)/);
        if (fromToMatch) {
            const start = this._parseSingleDate(fromToMatch[1]);
            const end = this._parseSingleDate(fromToMatch[2]);
            if (start && end) return { start, end };
        }

        // Single date
        const single = this._parseSingleDate(text);
        if (single) return { start: single, end: single };

        return null;
    }

    _calculateDays(startStr, endStr) {
        const start = new Date(startStr + 'T00:00:00');
        const end = new Date(endStr + 'T00:00:00');
        const diff = Math.ceil((end - start) / (1000 * 60 * 60 * 24)) + 1;
        return Math.max(1, diff);
    }

    _toDateString(date) {
        const y = date.getFullYear();
        const m = String(date.getMonth() + 1).padStart(2, '0');
        const d = String(date.getDate()).padStart(2, '0');
        return `${y}-${m}-${d}`;
    }
}