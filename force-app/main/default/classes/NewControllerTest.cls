@isTest
private class NewControllerTest {
    
    @TestSetup
    static void makeTestData() {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User testUser = new User(
            Alias = 'tuser',
            Email = 'testuser@example.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'Test User',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = p.Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            UserName = 'testuser' + System.currentTimeMillis() + '@test.com'
        );
        insert testUser;
        
        // ✅ Create MULTIPLE branches for testing
        List<Branch__c> branches = new List<Branch__c>{
            new Branch__c(Branch_Name__c = 'Mumbai Branch', City__c = 'Mumbai', State__c = 'MH'),
            new Branch__c(Branch_Name__c = 'Pune Branch', City__c = 'Pune', State__c = 'MH'),
            new Branch__c(Branch_Name__c = 'Delhi Branch', City__c = 'Delhi', State__c = 'DL')
        };
        insert branches;
    }

    private static Id getTestEmployeeId() {
        return [SELECT Id FROM User WHERE Email = 'testuser@example.com' LIMIT 1].Id;
    }

    private static Id getTestBranchId() {
        return [SELECT Id FROM Branch__c LIMIT 1].Id;
    }

    @isTest static void testCreateAttendanceOffice() {
        Id empId = getTestEmployeeId();
        Id branchId = getTestBranchId();
        
        Map<String, Object> payload = new Map<String, Object>{
            'Employee_Name__c' => empId,
            'Date__c' => '2025-12-11',
            'Check_In_Time__c' => '2025-12-11T09:00:00Z',
            'Status__c' => 'Present',
            'Work_Location__c' => 'Work from Office',
            'Branch_Name__c' => branchId  // ✅ REQUIRED
        };

        Test.startTest();
        NewController.createAttendance(payload);
        Test.stopTest();
    }

    @isTest static void testCreateAttendanceClientPlace() {
        Id empId = getTestEmployeeId();
        Id branchId = getTestBranchId();  // ✅ REQUIRED EVEN FOR CLIENT PLACE
        
        Map<String, Object> payload = new Map<String, Object>{
            'Employee_Name__c' => empId,
            'Date__c' => '2025-12-11',
            'Check_In_Time__c' => '2025-12-11T09:00:00Z',
            'Status__c' => 'Present',
            'Work_Location__c' => 'Client Place',
            'Client_Place_Details__c' => 'Client ABC',
            'Branch_Name__c' => branchId  // ✅ REQUIRED FIELD
        };

        Test.startTest();
        NewController.createAttendance(payload);
        Test.stopTest();
    }

    @isTest static void testCreateAttendanceFieldWork() {
        Id empId = getTestEmployeeId();
        Id branchId = getTestBranchId();  // ✅ REQUIRED EVEN FOR FIELD WORK
        
        Map<String, Object> payload = new Map<String, Object>{
            'Employee_Name__c' => empId,
            'Date__c' => '2025-12-11',
            'Check_In_Time__c' => '2025-12-11T09:00:00Z',
            'Status__c' => 'Present',
            'Work_Location__c' => 'Field Work',
            'Field_Work_Details__c' => 'Field Site 12',
            'Branch_Name__c' => branchId  // ✅ REQUIRED FIELD
        };

        Test.startTest();
        NewController.createAttendance(payload);
        Test.stopTest();
    }

    @isTest static void testCreateAttendanceWFH() {
        Id empId = getTestEmployeeId();
        Id branchId = getTestBranchId();  // ✅ REQUIRED EVEN FOR WFH
        
        Map<String, Object> payload = new Map<String, Object>{
            'Employee_Name__c' => empId,
            'Date__c' => '2025-12-11',
            'Status__c' => 'Present',
            'Work_Location__c' => 'Work from Home',
            'WFH_Reason__c' => 'Sick',
            'Branch_Name__c' => branchId  // ✅ REQUIRED FIELD
        };

        Test.startTest();
        NewController.createAttendance(payload);
        Test.stopTest();
    }

    @isTest static void testCreateAttendancePhotos() {
        Id empId = getTestEmployeeId();
        Id branchId = getTestBranchId();
        
        String mockImg = EncodingUtil.base64Encode(Blob.valueOf('test_image'));
        
        Map<String, Object> payload = new Map<String, Object>{
            'Employee_Name__c' => empId,
            'Date__c' => '2025-12-11',
            'Check_In_Time__c' => '2025-12-11T09:00:00Z',
            'Status__c' => 'Present',
            'Work_Location__c' => 'Work from Office',
            'Branch_Name__c' => branchId,  // ✅ REQUIRED
            'Check_In_Photo_B64' => mockImg,
            'Check_In_Photo_Name' => 'checkin.jpg',
            'Check_Out_Photo_B64' => mockImg,
            'Check_Out_Photo_Name' => 'checkout.jpg'
        };

        Test.startTest();
        NewController.createAttendance(payload);
        Test.stopTest();
    }

    @isTest static void testValidationErrors() {
        NewController.createAttendance(null);
        NewController.createAttendance(new Map<String, Object>());
    }

    @isTest static void testTestNewFieldsAccess() {
        Test.startTest();
        NewController.testNewFieldsAccess();
        Test.stopTest();
    }

    @isTest static void testDebugAttendanceRecord() {
        Id empId = getTestEmployeeId();
        Id branchId = getTestBranchId();
        
        // ✅ ALL records MUST have Branch__c
        List<Employee_Attendance__c> testAtts = new List<Employee_Attendance__c>();
        testAtts.add(new Employee_Attendance__c(
            Employee_Name__c = empId, Date__c = Date.today(),
            Work_Location__c = 'Work from Office', Branch__c = branchId, Status__c = 'Present'
        ));
        testAtts.add(new Employee_Attendance__c(
            Employee_Name__c = empId, Date__c = Date.today(),
            Work_Location__c = 'Client Place', Branch__c = branchId, 
            Client_Place_Details__c = 'Test', Status__c = 'Present'
        ));
        insert testAtts;

        Test.startTest();
        NewController.debugAttendanceRecord(testAtts[0].Id);
        NewController.debugAttendanceRecord('');
        Test.stopTest();
    }
}