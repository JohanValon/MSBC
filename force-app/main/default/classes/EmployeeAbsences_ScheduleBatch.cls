public with sharing class EmployeeAbsences_ScheduleBatch implements Database.Batchable<sObject> , Database.Stateful , Database.AllowsCallouts , Schedulable {
    Integer numberOfAbsences = 0;
    private String originalTransactionId;
    String query = 'SELECT (SELECT Id, Migration_ID__c, flair__Day__c, flair__Workload_Amount_in_Minutes__c FROM flair__Absence_Days__r WHERE flair__Workload_Amount_in_Minutes__c  > 0), flair__Employee_Absence_Category__r.flair__Absence_Category__r.Absence_Code__c, flair__Start_Date__c, flair__Employee_Name__c, flair__EmployeeId__c FROM flair__Absence__c WHERE flair__Approval_Status__c  = \'APPROVED\'';

    public Database.QueryLocator start(Database.BatchableContext bc){
        this.originalTransactionId = Nebula.Logger.getTransactionId();
        Nebula.Logger.info('Starting EmployeeAbsences_ScheduleBatch');
        Nebula.Logger.saveLog();
        return Database.getQueryLocator(query);
    }

    public void execute(Database.BatchableContext bc, List<flair__Absence__c> scope){
        Id[] employeeIds = new List<Id>();
        for(flair__Absence__c absence : scope){
            employeeIds.add(absence.flair__EmployeeId__c);
        }

        Map<Id, flair__Employee__c> employeeMap = new Map<Id, flair__Employee__c>([SELECT Company_Personnel_Number__c, ERP_Resource_No__c, flair__Employee_Number__c, flair__Entity__r.flair__Migration_ID__c  FROM flair__Employee__c WHERE Id IN :employeeIds]);
        Map<String, MSBCAPI.CreateEmployeeAbsencesRequest> createEmployeeMap = new Map<String, MSBCAPI.CreateEmployeeAbsencesRequest>();
        CreateEmployeeRequestParams[] createEmployeeList = new List<CreateEmployeeRequestParams>();

        for(flair__Absence__c absence : scope){ 
            for(flair__Absence_Day__c absenceDay : absence.flair__Absence_Days__r){ 
                if (String.isBlank(absenceDay.Migration_ID__c) && !String.isBlank(absence.flair__Employee_Absence_Category__r.flair__Absence_Category__r.Absence_Code__c)) {
                    MSBCAPI.CreateEmployeeAbsencesRequest employeeRequest = new MSBCAPI.CreateEmployeeAbsencesRequest();
                    employeeRequest.employeeNo = employeeMap.get(absence.flair__EmployeeId__c).Company_Personnel_Number__c;
                    employeeRequest.resourceNo = employeeMap.get(absence.flair__EmployeeId__c).ERP_Resource_No__c;
                    employeeRequest.fromDate = DateTime.newInstance(absenceDay.flair__Day__c, Time.newInstance(0,0,0,0)).format('yyyy-MM-dd');
                    employeeRequest.quantityBase = absenceDay.flair__Workload_Amount_in_Minutes__c / 60;
                    employeeRequest.causeOfAbsenceCode = absence.flair__Employee_Absence_Category__r.flair__Absence_Category__r.Absence_Code__c;

                    CreateEmployeeRequestParams params = new CreateEmployeeRequestParams();
                    params.companyId = employeeMap.get(absence.flair__EmployeeId__c).flair__Entity__r.flair__Migration_ID__c;
                    params.absenceDayId = absenceDay.Id;
                    params.data = employeeRequest;
                    createEmployeeList.add(params);
                }
            }
        }
        Nebula.Logger.info('CreateEmployeeAbsencesRequest records').setMessage(JSON.serialize(createEmployeeList));
        MSBCAPI.CreateEmployeeAbsencesResponse[] responses = new List<MSBCAPI.CreateEmployeeAbsencesResponse>();
        Map<Id, String> absenceDayIdToMigrationId = new Map<Id, String>();
        for (CreateEmployeeRequestParams params : createEmployeeList){
            MSBCAPI.CreateEmployeeAbsencesResponse response = MSBCAPI.createEmployeeAbscence(params.companyId, params.data);
            responses.add(response);
            absenceDayIdToMigrationId.put(params.absenceDayId, response.id);    
        }
        Nebula.Logger.info('CreateEmployeeAbsencesResponse records').setMessage(JSON.serialize(responses));

        flair__Absence_Day__c[] absenceDaysToUpdate = new List<flair__Absence_Day__c>();
        for(flair__Absence__c absence : scope){ 
            for(flair__Absence_Day__c absenceDay : absence.flair__Absence_Days__r){ 
                if (String.isBlank(absenceDay.Migration_ID__c)) {
                    absenceDay.Migration_ID__c = absenceDayIdToMigrationId.get(absenceDay.Id);
                    absenceDaysToUpdate.add(absenceDay);
                }
            }
        }
        Database.SaveResult[] results = Database.update(absenceDaysToUpdate, true, AccessLevel.SYSTEM_MODE);
        Nebula.Logger.info('flair__Absence_Day__c records updated', results);
        Nebula.Logger.saveLog();
        numberOfAbsences += scope.size();
    }
   
    public void finish(Database.BatchableContext bc){
        Nebula.Logger.info('Number of Absences processed: ' + numberOfAbsences);
        Nebula.Logger.setParentLogTransactionId(this.originalTransactionId);
        Nebula.Logger.info('Finishing running TimeEntries_ScheduleBatch');
        Nebula.Logger.saveLog();
    }

    public void execute(SchedulableContext sc) {
        Database.executeBatch(new EmployeeAbsences_ScheduleBatch(), 100);
    }

    public static void start(){
        String jobName = 'EmployeeAbsences_ScheduleBatch' + ' - ' + Datetime.now().format();
        String cron = '0 0 * * * ?'; //Run Every hour
        Nebula.Logger.info('Scheduling EmployeeAbsences_ScheduleBatch with cron: ' + cron);
        System.schedule(jobName, cron, new EmployeeAbsences_ScheduleBatch());
    }

    public class CreateEmployeeRequestParams {
        public String companyId { get; set; }
        public String absenceDayId { get; set; }
        public MSBCAPI.CreateEmployeeAbsencesRequest data { get; set; }
    }
}