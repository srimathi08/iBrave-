public without sharing class AttendanceController {
    
    @AuraEnabled
    public static Map<String, Object> getCurrentAttendanceStatus() {
        try {
            String userId = UserInfo.getUserId();
            List<String> fields = new List<String>{
                'Id', 'Check_In_Time__c', 'Check_Out_Time__c', 'Status__c', 
                'Total_Hours__c', 'Check_In_Location__latitude__s', 'Check_In_Location__longitude__s',
                'Check_Out_Location__latitude__s', 'Check_Out_Location__longitude__s'
            };
            
            String whereClause = 'User__c = \'' + userId + '\' AND Date__c = TODAY AND Is_Active__c = true';
            List<SObject> records = QueryOperationHandler.getRecords('Attendance_Record__c', fields, whereClause, 'Check_In_Time__c DESC', 1);
            
            Map<String, Object> result = new Map<String, Object>();
            
            if (!records.isEmpty()) {
                Attendance_Record__c attendanceRecord = (Attendance_Record__c) records[0];
                result.put('hasActiveSession', true);
                result.put('attendanceRecord', attendanceRecord);
                result.put('isCheckedIn', attendanceRecord.Status__c == 'Checked In');
                
                if (attendanceRecord.Check_In_Time__c != null && attendanceRecord.Status__c == 'Checked In') {
                    Long elapsedTime = (System.now().getTime() - attendanceRecord.Check_In_Time__c.getTime()) / 1000;
                    result.put('elapsedSeconds', elapsedTime);
                }
            } else {
                result.put('hasActiveSession', false);
                result.put('isCheckedIn', false);
            }
            
            return result;
        } catch (Exception e) {
            throw new AuraHandledException('Error getting attendance status: ' + e.getMessage());
        }
    }
    
    @AuraEnabled
    public static Map<String, Object> checkIn(Decimal latitude, Decimal longitude, String address, String imageId) {
        try {
            String userId = UserInfo.getUserId();
            
            // Check if there's already an active session
            Map<String, Object> currentStatus = getCurrentAttendanceStatus();
            if ((Boolean) currentStatus.get('hasActiveSession')) {
                throw new AuraHandledException('You already have an active attendance session.');
            }
            
            Attendance_Record__c newRecord = new Attendance_Record__c();
            newRecord.User__c = userId;
            newRecord.Check_In_Time__c = System.now();
            newRecord.Status__c = 'Checked In';
            newRecord.Date__c = Date.today();
            newRecord.Is_Active__c = true;
            newRecord.Check_In_Address__c = address;
            
            if (latitude != null && longitude != null) {
                newRecord.Check_In_Location__latitude__s = latitude;
                newRecord.Check_In_Location__longitude__s = longitude;
            }
            
            if (String.isNotBlank(imageId)) {
                newRecord.Check_In_Image__c = imageId;
            }
            
            List<SObject> insertedRecords = DMLOperationHandler.insertRecords(new List<SObject>{newRecord});
            
            Map<String, Object> result = new Map<String, Object>();
            result.put('success', true);
            result.put('message', 'Successfully checked in');
            result.put('attendanceRecord', insertedRecords[0]);
            
            return result;
        } catch (Exception e) {
            throw new AuraHandledException('Error during check-in: ' + e.getMessage());
        }
    }
    
    @AuraEnabled
    public static Map<String, Object> checkOut(Decimal latitude, Decimal longitude, String address, String imageId) {
        try {
            String userId = UserInfo.getUserId();
            
            // Get active attendance record
            Map<String, Object> currentStatus = getCurrentAttendanceStatus();
            if (!(Boolean) currentStatus.get('hasActiveSession')) {
                throw new AuraHandledException('No active attendance session found.');
            }
            
            Attendance_Record__c attendanceRecord = (Attendance_Record__c) currentStatus.get('attendanceRecord');
            
            attendanceRecord.Check_Out_Time__c = System.now();
            attendanceRecord.Status__c = 'Checked Out';
            attendanceRecord.Is_Active__c = false;
            attendanceRecord.Check_Out_Address__c = address;
            
            if (latitude != null && longitude != null) {
                attendanceRecord.Check_Out_Location__latitude__s = latitude;
                attendanceRecord.Check_Out_Location__longitude__s = longitude;
            }
            
            if (String.isNotBlank(imageId)) {
                attendanceRecord.Check_Out_Image__c = imageId;
            }
            
            // Calculate total hours
            if (attendanceRecord.Check_In_Time__c != null) {
                Long timeDiffMillis = attendanceRecord.Check_Out_Time__c.getTime() - attendanceRecord.Check_In_Time__c.getTime();
                Decimal totalHours = Decimal.valueOf(timeDiffMillis) / (1000 * 60 * 60);
                attendanceRecord.Total_Hours__c = totalHours.setScale(2);
            }
            
            DMLOperationHandler.updateRecords(new List<SObject>{attendanceRecord});
            
            Map<String, Object> result = new Map<String, Object>();
            result.put('success', true);
            result.put('message', 'Successfully checked out');
            result.put('attendanceRecord', attendanceRecord);
            
            return result;
        } catch (Exception e) {
            throw new AuraHandledException('Error during check-out: ' + e.getMessage());
        }
    }
    
    @AuraEnabled
    public static List<Map<String, Object>> getAttendanceHistory(Integer limitCount) {
        try {
            String userId = UserInfo.getUserId();
            List<String> fields = new List<String>{
                'Id', 'Name', 'Check_In_Time__c', 'Check_Out_Time__c', 'Status__c', 
                'Total_Hours__c', 'Date__c', 'Check_In_Address__c', 'Check_Out_Address__c'
            };
            
            String whereClause = 'User__c = \'' + userId + '\'';
            String orderBy = 'Date__c DESC, Check_In_Time__c DESC';
            
            List<SObject> records = QueryOperationHandler.getRecords('Attendance_Record__c', fields, whereClause, orderBy, limitCount);
            
            List<Map<String, Object>> result = new List<Map<String, Object>>();
            for (SObject record : records) {
                Attendance_Record__c att = (Attendance_Record__c) record;
                Map<String, Object> attMap = new Map<String, Object>();
                attMap.put('Id', att.Id);
                attMap.put('Name', att.Name);
                attMap.put('Date', att.Date__c);
                attMap.put('CheckInTime', att.Check_In_Time__c);
                attMap.put('CheckOutTime', att.Check_Out_Time__c);
                attMap.put('Status', att.Status__c);
                attMap.put('TotalHours', att.Total_Hours__c);
                attMap.put('CheckInAddress', att.Check_In_Address__c);
                attMap.put('CheckOutAddress', att.Check_Out_Address__c);
                result.add(attMap);
            }
            
            return result;
        } catch (Exception e) {
            throw new AuraHandledException('Error getting attendance history: ' + e.getMessage());
        }
    }
    
 	    
   @AuraEnabled(cacheable=true)
public static User getUserDetails() {
    return [SELECT Name, Email, Profile.Name,Manager.Name FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];

    }
   
    
}