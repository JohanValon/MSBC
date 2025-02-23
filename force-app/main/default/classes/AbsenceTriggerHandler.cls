public with sharing class AbsenceTriggerHandler {
  public static Boolean isExecuteUpdate = false;
  public AbsenceTriggerHandler() {}

  public void onBeforeDelete(Map<Id, flair__Absence__c> oldAbsences) {
    flair__Absence_Day__c[] absenceDays = [SELECT Id, Migration_ID__c, flair__Absence__c, flair__Employee__c FROM flair__Absence_Day__c 
        WHERE Migration_ID__c != null AND flair__Absence__c IN :oldAbsences.keySet() AND flair__Absence__r.flair__Approval_Status__c = 'APPROVED'];

    ChainManager.instance
      .add(new AbsenceDayTriggerHandler.DeleteRelatedEmployeeAbsencesInMSBC(absenceDays))
      .startChain();
  }
    
  public void onBeforeUpdate(Map<Id, flair__Absence__c> oldAbsences, Map<Id, flair__Absence__c> newAbsences) {
    Set<Id> oldAbsenceIds = new Set<Id>();
    for(Id key : newAbsences.keySet()) {
      // if the absence is approved and the approval status has changed or the start or end date has changed
      if(newAbsences.get(key).flair__Approval_Status__c == 'APPROVED' && (
          oldAbsences.get(key).flair__Start_Date__c != newAbsences.get(key).flair__Start_Date__c || oldAbsences.get(key).flair__End_Date__c != newAbsences.get(key).flair__End_Date__c)) {
        oldAbsenceIds.add(key);
        isExecuteUpdate = true;
      }
    }
    if(isExecuteUpdate){
      flair__Absence_Day__c[] absenceDays = [SELECT Id, Migration_ID__c, flair__Absence__c, flair__Employee__c FROM flair__Absence_Day__c 
        WHERE Migration_ID__c != null AND flair__Absence__c IN :oldAbsenceIds];
      ChainManager.instance
        .add(new AbsenceDayTriggerHandler.DeleteRelatedEmployeeAbsencesInMSBC(absenceDays))
        .startChain();
      isExecuteUpdate = false;
    }
  }

  public void onAfterUpdate(Map<Id, flair__Absence__c> oldAbsences, Map<Id, flair__Absence__c> newAbsences) {
    Set<Id> newAbsenceIds = new Set<Id>();
    for(Id key : newAbsences.keySet()) {
      // if the absence is approval status has changed and it's new value is approved or the approval status is approvoed and the start or end date has changed
      // (oldAbsences.get(key).flair__Approval_Status__c != newAbsences.get(key).flair__Approval_Status__c && newAbsences.get(key).flair__Approval_Status__c == 'APPROVED') ||
      // if the absence is approved and the approval status has changed or the start or end date has changed
      if((newAbsences.get(key).flair__Approval_Status__c == 'APPROVED' && 
          (oldAbsences.get(key).flair__Start_Date__c != newAbsences.get(key).flair__Start_Date__c || oldAbsences.get(key).flair__End_Date__c != newAbsences.get(key).flair__End_Date__c))) { 
        newAbsenceIds.add(key);
        isExecuteUpdate = true;
      }
    }
      if(isExecuteUpdate){
          ChainManager.instance
            .add(new CreateRelatedEmployeeAbsencesInMSBC(newAbsences.keySet()))
            .startChain();
          isExecuteUpdate = false;
      }
   }

  public class CreateRelatedEmployeeAbsencesInMSBC extends QueueLink implements Database.AllowsCallouts {
    Set<Id> newAbsencesIds;
    Set<Id> absencesDaysIds = new Set<Id>();

    public CreateRelatedEmployeeAbsencesInMSBC(Set<Id> newAbsencesIds) {
      this.newAbsencesIds = newAbsencesIds;
    }
      
    public CreateRelatedEmployeeAbsencesInMSBC(Set<Id> newAbsencesIds, Set<Id> absencesDaysIds) {
      this.newAbsencesIds = newAbsencesIds;
      this.absencesDaysIds = absencesDaysIds;  
    }

    protected override void job() {
      flair__Absence__c[] scope = new flair__Absence__c[]{};
      if(!absencesDaysIds.isEmpty()){
			  scope = [SELECT (SELECT Id, Migration_ID__c, flair__Day__c, flair__Workload_Amount_in_Minutes__c FROM flair__Absence_Days__r 
                          WHERE flair__Workload_Amount_in_Minutes__c > 0 AND Id IN :absencesDaysIds), flair__Employee_Absence_Category__r.flair__Absence_Category__r.Absence_Code__c, flair__Start_Date__c, flair__Employee_Name__c, flair__EmployeeId__c 
                FROM flair__Absence__c WHERE flair__Approval_Status__c = 'APPROVED' AND Id IN :newAbsencesIds]; 
      } else {
          scope = [SELECT (SELECT Id, Migration_ID__c, flair__Day__c, flair__Workload_Amount_in_Minutes__c FROM flair__Absence_Days__r 
                            WHERE flair__Workload_Amount_in_Minutes__c > 0), flair__Employee_Absence_Category__r.flair__Absence_Category__r.Absence_Code__c, flair__Start_Date__c, flair__Employee_Name__c, flair__EmployeeId__c 
                  FROM flair__Absence__c WHERE flair__Approval_Status__c = 'APPROVED' AND Id IN :newAbsencesIds]; 
      }
      Logger.info('scope records').setMessage(JSON.serialize(scope));

      Id[] employeeIds = new List<Id>();
      for(flair__Absence__c absence : scope){
        employeeIds.add(absence.flair__EmployeeId__c);
      }

      Map<Id, flair__Employee__c> employeeMap = new Map<Id, flair__Employee__c>([SELECT ERP_Resource_No__c, flair__Employee_Number__c, flair__Entity__r.flair__Migration_ID__c FROM flair__Employee__c WHERE Id IN :employeeIds AND flair__Entity__r.Is_MSBC_Synched__c = true]);
      Map<String, MSBCAPI.CreateEmployeeAbsencesRequest> createEmployeeMap = new Map<String, MSBCAPI.CreateEmployeeAbsencesRequest>();
      MSBCAPI.CreateEmployeeRequestParams[] createEmployeeList = new List<MSBCAPI.CreateEmployeeRequestParams>();

      for(flair__Absence__c absence : scope){ 
        for(flair__Absence_Day__c absenceDay : absence.flair__Absence_Days__r){ 
          //if (String.isBlank(absenceDay.Migration_ID__c)) {
            MSBCAPI.CreateEmployeeAbsencesRequest employeeRequest = new MSBCAPI.CreateEmployeeAbsencesRequest();
            employeeRequest.employeeNo = 'CM-00007';
            employeeRequest.resourceNo = employeeMap.get(absence.flair__EmployeeId__c).ERP_Resource_No__c;
            employeeRequest.fromDate = DateTime.newInstance(absenceDay.flair__Day__c, Time.newInstance(0,0,0,0)).format('yyyy-MM-dd');
            employeeRequest.quantityBase = absenceDay.flair__Workload_Amount_in_Minutes__c / 60;
            employeeRequest.causeOfAbsenceCode = absence.flair__Employee_Absence_Category__r.flair__Absence_Category__r.Absence_Code__c;

            MSBCAPI.CreateEmployeeRequestParams params = new MSBCAPI.CreateEmployeeRequestParams();
            params.companyId = employeeMap.get(absence.flair__EmployeeId__c).flair__Entity__r.flair__Migration_ID__c;
            params.absenceDayId = absenceDay.Id;
            params.data = employeeRequest;
            createEmployeeList.add(params);
          //}
        }
      }
      Logger.info('CreateEmployeeAbsencesRequest records').setMessage(JSON.serialize(createEmployeeList));
      MSBCAPI.CreateEmployeeAbsencesResponse[] responses = new List<MSBCAPI.CreateEmployeeAbsencesResponse>();
      Map<Id, String> absenceDayIdToMigrationId = new Map<Id, String>();
      for (MSBCAPI.CreateEmployeeRequestParams params : createEmployeeList){
        MSBCAPI.CreateEmployeeAbsencesResponse response = MSBCAPI.createEmployeeAbscence(params.companyId, params.data);
        responses.add(response);
        absenceDayIdToMigrationId.put(params.absenceDayId, response.id);  
      }
      Logger.info('CreateEmployeeAbsencesResponse records').setMessage(JSON.serialize(responses));

      flair__Absence_Day__c[] absenceDaysToUpdate = new List<flair__Absence_Day__c>();
      for(flair__Absence__c absence : scope){ 
        for(flair__Absence_Day__c absenceDay : absence.flair__Absence_Days__r){ 
          //if (String.isBlank(absenceDay.Migration_ID__c)) {
            absenceDay.Migration_ID__c = absenceDayIdToMigrationId.get(absenceDay.Id);
            absenceDaysToUpdate.add(absenceDay);
          //}
        }
      }
      Database.SaveResult[] results = Database.update(absenceDaysToUpdate, true, AccessLevel.SYSTEM_MODE);
      Logger.info('flair__Absence_Day__c records updated', results);
      Logger.saveLog();
    }
  }
}