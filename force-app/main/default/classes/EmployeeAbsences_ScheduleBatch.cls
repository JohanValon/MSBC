public with sharing class EmployeeAbsences_ScheduleBatch implements Database.Batchable<sObject> , Database.Stateful , Database.AllowsCallouts , Schedulable {
    Integer numberOfAbsences = 0;
    String query = 'SELECT (SELECT Id, Migration_ID__c, flair__Workload_Amount_in_Minutes__c FROM flair__Absence_Days__r WHERE flair__Workload_Amount_in_Minutes__c  > 0), flair__Employee_Absence_Category__r.flair__Absence_Category__r.Absence_Code__c, flair__Start_Date__c, flair__Amount__c, flair__Employee_Name__c, flair__EmployeeId__c FROM flair__Absence__c WHERE flair__Approval_Status__c  = \'APPROVED\'';

    public Database.QueryLocator start(Database.BatchableContext bc){
        return Database.getQueryLocator(query);
    }

    public void execute(Database.BatchableContext bc, List<flair__Absence__c> scope){
        List<Id> employeeIds = new List<Id>();
        for(flair__Absence__c absence : scope){
            employeeIds.add(absence.flair__EmployeeId__c);
        }

        Map<Id, flair__Employee__c> employeeMap = new Map<Id, flair__Employee__c>([SELECT ERP_Resource_No__c, flair__Entity__r.flair__Migration_ID__c  FROM flair__Employee__c WHERE Id IN :employeeIds]);
        Map<String, MSBCAPI.CreateEmployeeRequest> createEmployeeMap = new Map<String, MSBCAPI.CreateEmployeeRequest>();
        List<CreateEmployeeRequestParams> createEmployeeList = new List<CreateEmployeeRequestParams>();

        for(flair__Absence__c absence : scope){ 
            for(flair__Absence_Day__c absenceDay : absence.flair__Absence_Days__r){ 
                MSBCAPI.CreateEmployeeRequest employeeRequest = new MSBCAPI.CreateEmployeeRequest();
                employeeRequest.employeeNo = 'TESTMITARBEITER';
                employeeRequest.resourceNo = employeeMap.get(absence.flair__EmployeeId__c).ERP_Resource_No__c;
                employeeRequest.fromDate = DateTime.newInstance(absence.flair__Start_Date__c, Time.newInstance(0,0,0,0)).format('yyyy-MM-dd');
                employeeRequest.quantityBase = absenceDay.flair__Workload_Amount_in_Minutes__c / 60;
                employeeRequest.causeOfAbsenceCode = absence.flair__Employee_Absence_Category__r.flair__Absence_Category__r.Absence_Code__c;

                CreateEmployeeRequestParams params = new CreateEmployeeRequestParams();
                params.companyId = employeeMap.get(absence.flair__EmployeeId__c).flair__Entity__r.flair__Migration_ID__c;
                params.absenceDayId = absenceDay.Id;
                params.data = employeeRequest;
                createEmployeeList.add(params);
            }
        }
        Map<Id, String> absenceDayIdToMigrationId = new Map<Id, String>();
        for (CreateEmployeeRequestParams params : createEmployeeList){
            MSBCAPI.CreateEmployeeResponse response = MSBCAPI.createEmployeeAbscence(params.companyId, params.data);
            absenceDayIdToMigrationId.put(params.absenceDayId, response.id);    
        }


        List<flair__Absence_Day__c> absenceDaysToUpdate = new List<flair__Absence_Day__c>();
        for(flair__Absence__c absence : scope){ 
            for(flair__Absence_Day__c absenceDay : absence.flair__Absence_Days__r){ 
                absenceDay.Migration_ID__c = absenceDayIdToMigrationId.get(absenceDay.Id);
                absenceDaysToUpdate.add(absenceDay);
            }
        }
        update absenceDaysToUpdate;
        numberOfAbsences += scope.size();
    }
   
    public void finish(Database.BatchableContext bc){
        System.debug('Number of Absences processed: ' + numberOfAbsences);
    }

    public  void execute(SchedulableContext sc) {
        Database.executeBatch(new EmployeeAbsences_ScheduleBatch());
    }

    public static void start(Integer hour){
        String jobName = 'TimeEntries_ScheduleBatch';
        if (hour == 0) 
            Database.executebatch(new TimeEntries_ScheduleBatch());
        else {
            jobName += ' - ' + Datetime.now().format();
            String cron = '0 0 ' + String.valueof(hour) + ' * * ?';
            System.schedule(jobName, cron, new TimeEntries_ScheduleBatch());
        }
    }

    public class CreateEmployeeRequestParams {
        public String companyId { get; set; }
        public String absenceDayId { get; set; }
        public MSBCAPI.CreateEmployeeRequest data { get; set; }
    }
}