public with sharing class AbsenceTriggerHandler {
  public AbsenceTriggerHandler() {}

  public void onBeforeDelete(Map<Id, flair__Absence__c> oldAbsences) {
    ChainManager.instance
    .add(new DeleteRelatedEmployeeAbsencesInMSBC(oldAbsences.keySet()))
    .startChain();
  }

  public void onAfterUpdate(Map<Id, flair__Absence__c> oldAbsences, Map<Id, flair__Absence__c> newAbsences) {
    ChainManager.instance
    .add(new DeleteRelatedEmployeeAbsencesInMSBC(oldAbsences.keySet()))
    .add(new CreateRelatedEmployeeAbsencesInMSBC(newAbsences.keySet()))
    .startChain();
  }

  public class DeleteRelatedEmployeeAbsencesInMSBC extends QueueLink {
    Set<Id> oldAbsencesIds; 

    public DeleteRelatedEmployeeAbsencesInMSBC(Set<Id> oldAbsencesIds) {
      this.oldAbsencesIds = oldAbsencesIds;
    }

    protected override void job() {
      flair__Absence_Day__c[] absenceDays = [SELECT Id, Migration_ID__c, flair__Absence__c, flair__Absence__r.flair__EmployeeId__c FROM flair__Absence_Day__c 
        WHERE Migration_ID__c != null AND flair__Absence__c IN :oldAbsencesIds AND flair__Absence__r.flair__Approval_Status__c = 'APPROVED'];
      
      Id[] employeeIds = new List<Id>();
      for(flair__Absence_Day__c absenceDay : absenceDays){
        employeeIds.add(absenceDay.flair__Absence__r.flair__EmployeeId__c);
      }

      flair__Employee__c[] employees = [SELECT flair__Entity__r.flair__Migration_ID__c FROM flair__Employee__c WHERE Id IN :employeeIds AND flair__Entity__r.Is_MSBC_Synched__c = true];
      MSBCAPI.DeleteEmployeeAbsencesRequestParams[] deleteEmployeeList = new List<MSBCAPI.DeleteEmployeeAbsencesRequestParams>();
      for (flair__Employee__c employee : employees) {
        for (flair__Absence_Day__c absenceDay : absenceDays) {
          MSBCAPI.DeleteEmployeeAbsencesRequestParams params = new MSBCAPI.DeleteEmployeeAbsencesRequestParams();
          params.companyId = employee.flair__Entity__r.flair__Migration_ID__c;
          params.absenceDayId = absenceDay.Migration_ID__c;
          deleteEmployeeList.add(params);
        }
      }
      Logger.info('DeleteEmployeeAbsencesRequestParams records').setMessage(JSON.serialize(deleteEmployeeList));
      Logger.saveLog();

      for(MSBCAPI.DeleteEmployeeAbsencesRequestParams params : deleteEmployeeList){
        MSBCAPI.deleteEmployeeAbsences(params.companyId, params.absenceDayId);
      }
    }
  }

  public class CreateRelatedEmployeeAbsencesInMSBC extends QueueLink {
    Set<Id> newAbsencesIds;

    public CreateRelatedEmployeeAbsencesInMSBC(Set<Id> newAbsencesIds) {
      this.newAbsencesIds = newAbsencesIds;
    }

    protected override void job() {
      flair__Absence__c[] scope = [SELECT (SELECT Id, Migration_ID__c, flair__Day__c, flair__Workload_Amount_in_Minutes__c FROM flair__Absence_Days__r 
        WHERE flair__Workload_Amount_in_Minutes__c > 0), flair__Employee_Absence_Category__r.flair__Absence_Category__r.Absence_Code__c, flair__Start_Date__c, flair__Employee_Name__c, flair__EmployeeId__c 
        FROM flair__Absence__c WHERE flair__Approval_Status__c = 'APPROVED' AND Id IN :newAbsencesIds]; 

      Id[] employeeIds = new List<Id>();
      for(flair__Absence__c absence : scope){
        employeeIds.add(absence.flair__EmployeeId__c);
      }

      Map<Id, flair__Employee__c> employeeMap = new Map<Id, flair__Employee__c>([SELECT ERP_Resource_No__c, flair__Employee_Number__c, flair__Entity__r.flair__Migration_ID__c FROM flair__Employee__c WHERE Id IN :employeeIds AND flair__Entity__r.Is_MSBC_Synched__c = true]);
      Map<String, MSBCAPI.CreateEmployeeAbsencesRequest> createEmployeeMap = new Map<String, MSBCAPI.CreateEmployeeAbsencesRequest>();
      MSBCAPI.CreateEmployeeRequestParams[] createEmployeeList = new List<MSBCAPI.CreateEmployeeRequestParams>();

      for(flair__Absence__c absence : scope){ 
        for(flair__Absence_Day__c absenceDay : absence.flair__Absence_Days__r){ 
          if (String.isBlank(absenceDay.Migration_ID__c)) {
            MSBCAPI.CreateEmployeeAbsencesRequest employeeRequest = new MSBCAPI.CreateEmployeeAbsencesRequest();
            employeeRequest.employeeNo = 'CM-00007'; //employeeMap.get(absence.flair__EmployeeId__c).ERP_Resource_No__c;
            employeeRequest.resourceNo = 'CM-00007'; //employeeMap.get(absence.flair__EmployeeId__c).ERP_Resource_No__c;
            employeeRequest.fromDate = DateTime.newInstance(absenceDay.flair__Day__c, Time.newInstance(0,0,0,0)).format('yyyy-MM-dd');
            employeeRequest.quantityBase = absenceDay.flair__Workload_Amount_in_Minutes__c / 60;
            employeeRequest.causeOfAbsenceCode = absence.flair__Employee_Absence_Category__r.flair__Absence_Category__r.Absence_Code__c;

            MSBCAPI.CreateEmployeeRequestParams params = new MSBCAPI.CreateEmployeeRequestParams();
            params.companyId = employeeMap.get(absence.flair__EmployeeId__c).flair__Entity__r.flair__Migration_ID__c;
            params.absenceDayId = absenceDay.Id;
            params.data = employeeRequest;
            createEmployeeList.add(params);
          }
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
          if (String.isBlank(absenceDay.Migration_ID__c)) {
            absenceDay.Migration_ID__c = absenceDayIdToMigrationId.get(absenceDay.Id);
            absenceDaysToUpdate.add(absenceDay);
          }
        }
      }
      Database.SaveResult[] results = Database.update(absenceDaysToUpdate, true, AccessLevel.SYSTEM_MODE);
      Logger.info('flair__Absence_Day__c records updated', results);
      Logger.saveLog();
    }
  }
}