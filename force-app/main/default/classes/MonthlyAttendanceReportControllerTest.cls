@IsTest
public class MonthlyAttendanceReportControllerTest {

    /* -------------------------
       CREATE USER
    --------------------------*/
    private static User createUser(String firstName, Id managerId, String dept, String empId) {

        Id profileId = UserInfo.getProfileId();

        User u = new User(
            FirstName = firstName,
            LastName = 'Test',
            Alias = firstName.length() >= 3 ? firstName.substring(0, 3) : 'tst',
            Email = firstName + '@test.com',
            Username = firstName + Datetime.now().getTime() + '@test.com',
            TimeZoneSidKey = 'Asia/Kolkata',
            LocaleSidKey = 'en_IN',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId = profileId,
            ManagerId = managerId,
            Department = dept,
            Employee_IDs__c = empId,
            Date_of_Joining__c = Date.today().addMonths(-6)
        );
        insert u;
        return u;
    }

    /* -------------------------
       MAIN TEST
    --------------------------*/
    @IsTest
    static void testGenerateMonthlyReport() {

        User manager = createUser('Manager', null, 'HR', '9001');
        User emp = createUser('Employee1', manager.Id, 'HR', '9002');

        Branch__c branch = new Branch__c(
            Branch_Name__c = 'Chennai HO',
            City__c = 'Chennai'
        );
        insert branch;

        Holiday__c holiday = new Holiday__c(
            Holiday_Type__c = 'Public Holiday',
            Holiday_Date__c = Date.newInstance(2025, 1, 26)
        );
        insert holiday;

        Leave_Type__c cl = new Leave_Type__c(
            Leave_Type_Name__c = 'Casual Leave',
            Leave_Code__c = 'CL'
        );

        Leave_Type__c lop = new Leave_Type__c(
            Leave_Type_Name__c = 'Loss of Pay',
            Leave_Code__c = 'LOP'
        );

        insert new List<Leave_Type__c>{ cl, lop };

        Employee_Attendance__c attendance = new Employee_Attendance__c(
            Employee_Name__c = emp.Id,
            Date__c = Date.newInstance(2025, 1, 10),
            Check_In_Time__c = System.now(),
            Status__c = 'Present',
            Work_Location__c = 'Work from Office',
            Branch__c = branch.Id
        );
        insert attendance;

        Leave_Request__c paidLeave = new Leave_Request__c(
            Employee__c = emp.Id,
            Start_Date__c = Date.newInstance(2025, 1, 15),
            End_Date__c = Date.newInstance(2025, 1, 15),
            Status__c = 'Approved',
            Leave_Type__c = cl.Id,
            Is_Half_Day__c = false,
            Total_Days__c = 1
        );
        insert paidLeave;

        Leave_Request__c lopLeave = new Leave_Request__c(
            Employee__c = emp.Id,
            Start_Date__c = Date.newInstance(2025, 1, 20),
            End_Date__c = Date.newInstance(2025, 1, 20),
            Status__c = 'Approved',
            Leave_Type__c = lop.Id,
            Is_Half_Day__c = false,
            Total_Days__c = 1
        );
        insert lopLeave;

        Test.startTest();

        Map<String, Object> result =
            MonthlyAttendanceReportController.generateMonthlyReport(
                1, 2025, 'HR', manager.Id
            );

        Test.stopTest();

        System.assertEquals(true, result.get('success'));
        System.assertEquals(1, result.get('totalEmployees'));

        List<Object> employees = (List<Object>) result.get('employees');
        System.assertEquals(1, employees.size());

        Map<String, Object> empData = (Map<String, Object>) employees[0];

        System.assertEquals('Employee1 Test', empData.get('employeeName'));
        System.assert(empData.containsKey('daysPayable'));
        System.assert(empData.containsKey('lopDays'));
    }

    /* -------------------------
       DEPARTMENTS
    --------------------------*/
    @IsTest
    static void testGetDepartments() {

        // Create user with department
        createUser('DeptUser', null, 'Finance', '8001');

        Test.startTest();
        List<String> depts = MonthlyAttendanceReportController.getDepartments();
        Test.stopTest();

        System.assert(depts.size() > 0);
        System.assert(depts.contains('Finance'));
    }

    /* -------------------------
       MANAGERS
    --------------------------*/
   @IsTest
static void testGetManagers() {

    // Create manager
    User manager = createUser('MainManager', null, 'HR', '7001');

    // Create employee reporting to manager
    createUser('SubEmployee', manager.Id, 'HR', '7002');

    Test.startTest();
    List<Map<String, String>> managers =
        MonthlyAttendanceReportController.getManagers();
    Test.stopTest();

    System.assert(managers.size() > 0);
    System.assert(managers[0].containsKey('Id'));
    System.assert(managers[0].containsKey('Name'));
}
 

    /* -------------------------
       EXCEL EXPORT
    --------------------------*/
    @IsTest
    static void testExportReportToExcel() {

        // Need at least one user for export logic
        createUser('ExportUser', null, 'IT', '6001');

        Test.startTest();

        Map<String, Object> result =
            MonthlyAttendanceReportController.exportReportToExcel(
                1, 2025, null, null
            );

        Test.stopTest();

        System.assertEquals(true, result.get('success'));
        System.assertNotEquals(null, result.get('fileData'));
        System.assertNotEquals(null, result.get('fileName'));
    }
}