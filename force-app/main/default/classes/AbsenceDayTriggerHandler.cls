public with sharing class AbsenceDayTriggerHandler {
  public AbsenceDayTriggerHandler() {}

  public static void onBeforeUpdate(Map<Id, flair__Absence_Day__c> oldAbsenceDays, Map<Id, flair__Absence_Day__c> newAbsenceDays) {
    Set<Id> newAbsenceIds = new Set<Id>();
    Set<Id> absenceDayIds = new Set<Id>();

    flair__Absence_Day__c[] absenceMSBCToDelete = new List<flair__Absence_Day__c>();
    for( Id key : oldAbsenceDays.keySet() ) {
      if(newAbsenceDays.get(key).Migration_ID__c != null && (oldAbsenceDays.get(key).Migration_ID__c == newAbsenceDays.get(key).Migration_ID__c) && (oldAbsenceDays.get(key).flair__Workload_Amount_in_Minutes__c != newAbsenceDays.get(key).flair__Workload_Amount_in_Minutes__c)) {
        absenceMSBCToDelete.add(oldAbsenceDays.get(key));
      }
    }

    ChainManager.instance
      .add(new DeleteRelatedEmployeeAbsencesInMSBC(absenceMSBCToDelete))
      .startChain();
  }

  public static void onAfterUpdate(Map<Id, flair__Absence_Day__c> oldAbsenceDays, Map<Id, flair__Absence_Day__c> newAbsenceDays) {
    Set<Id> newAbsenceIds = new Set<Id>();
    Set<Id> absenceDayIds = new Set<Id>();

    flair__Absence_Day__c[] absenceMSBCToDelete = new List<flair__Absence_Day__c>();
    for( Id key : oldAbsenceDays.keySet() ) {
      if(newAbsenceDays.get(key).Migration_ID__c != null && (oldAbsenceDays.get(key).Migration_ID__c == newAbsenceDays.get(key).Migration_ID__c) && (oldAbsenceDays.get(key).flair__Workload_Amount_in_Minutes__c != newAbsenceDays.get(key).flair__Workload_Amount_in_Minutes__c)) {
        newAbsenceIds.add(oldAbsenceDays.get(key).flair__Absence__c);
        absenceDayIds.add(key);
      }
    }

    ChainManager.instance
      .add(new AbsenceTriggerHandler.CreateRelatedEmployeeAbsencesInMSBC(newAbsenceIds, absenceDayIds))
      .startChain();
  }


  public static void onBeforeDelete(flair__Absence_Day__c[] oldAbsenceDays) {
      ChainManager.instance
      .add(new DeleteRelatedEmployeeAbsencesInMSBC(oldAbsenceDays))
      .startChain();
  }

  public class DeleteRelatedEmployeeAbsencesInMSBC extends QueueLink implements Database.AllowsCallouts {
    flair__Absence_Day__c[] absenceDays = new flair__Absence_Day__c[]{};

    public DeleteRelatedEmployeeAbsencesInMSBC(flair__Absence_Day__c[] absenceDays) {
      this.absenceDays = absenceDays;
    }

    protected override void job() {
      Logger.info('absenceDays records').setMessage(JSON.serialize(absenceDays));

      Id[] employeeIds = new List<Id>();
      for(flair__Absence_Day__c absenceDay : absenceDays){
        employeeIds.add(absenceDay.flair__Employee__c);
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
}