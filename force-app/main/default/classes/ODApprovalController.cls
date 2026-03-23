public without sharing class ODApprovalController {
public Boolean recordNotFound {get;set;} 

    public Id recordId {get;set;}

    public String recordName {get;set;}
    public String employeeName {get;set;}
    public String employeeInitial {get;set;}

    public String odDate {get;set;}
    public String workLocation {get;set;}
    public String checkInTime {get;set;}
    public String checkOutTime {get;set;}
    public Decimal hoursWorked {get;set;}

    public String attendanceStatus {get;set;}
    public String odReason {get;set;}
    public String odStatus {get;set;}

    public String approvalComments {get;set;}
    public String managerComments {get;set;}

   
    

    public String successMessage {get;set;}
    public String errorMessage {get;set;}



    private Employee_Attendance__c attendance;

    public ODApprovalController(){
recordNotFound = false;

        recordId = ApexPages.currentPage().getParameters().get('id');

        if(recordId == null){
            recordNotFound = true;
            return;
        }

        try{

            attendance = [
                SELECT Id,
                       Name,
                       Employee_Name__r.Name,
                       Date__c,
                       Work_Location__c,
                       Check_In_Time__c,
                       Check_Out_Time__c,
                       Hours_Worked__c,
                       OD_Reason__c,
                       OD_Approval_Status__c,
                       Approval_Comments__c
                FROM Employee_Attendance__c
                WHERE Id = :recordId
                LIMIT 1
            ];

            recordName = attendance.Name;
            employeeName = attendance.Employee_Name__r.Name;

            if(employeeName != null){
                employeeInitial = employeeName.substring(0,1);
            }

           // inside constructor
 if(attendance.Date__c != null){
    odDate = DateTime.newInstance(attendance.Date__c, Time.newInstance(0, 0, 0, 0))
                     .format('dd-MM-yyyy');
}
            workLocation = attendance.Work_Location__c;

            if(attendance.Check_In_Time__c != null)
                checkInTime = attendance.Check_In_Time__c.format('hh:mm a', 'Asia/Kolkata');

            if(attendance.Check_Out_Time__c != null)
                checkOutTime = attendance.Check_Out_Time__c.format('hh:mm a', 'Asia/Kolkata');

            hoursWorked = attendance.Hours_Worked__c;

            odReason = attendance.OD_Reason__c;
            odStatus = attendance.OD_Approval_Status__c;

            approvalComments = attendance.Approval_Comments__c;

            attendanceStatus = attendance.OD_Approval_Status__c;

        }
        catch(Exception e){
            recordNotFound = true;
        }
    }

    public PageReference approveOD(){
// ✅ ADD THIS BLOCK (FIRST LINE)
    if(attendance == null){
        errorMessage = 'Record not found.';
        return null;
    }

        try{

            attendance.OD_Approval_Status__c = 'Approved';
            attendance.Approval_Comments__c = managerComments;

            update attendance;

            successMessage = 'OD Request approved successfully.';
            odStatus = 'Approved';

        }catch(Exception e){

            errorMessage = 'Error approving request: ' + e.getMessage();
        }

        return null;
    }

    public PageReference rejectOD(){
// ✅ ADD THIS BLOCK (FIRST LINE)
    if(attendance == null){
        errorMessage = 'Record not found.';
        return null;
    }

        if(String.isBlank(managerComments)){
            errorMessage = 'Comments are required for rejection.';
            return null;
        }

        try{

            attendance.OD_Approval_Status__c = 'Rejected';
            attendance.Approval_Comments__c = managerComments;

            update attendance;

            successMessage = 'OD Request rejected.';
            odStatus = 'Rejected';

        }catch(Exception e){

            errorMessage = 'Error rejecting request: ' + e.getMessage();
        }

        return null;
    }


}