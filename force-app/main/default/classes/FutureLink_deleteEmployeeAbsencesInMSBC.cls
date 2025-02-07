public with sharing class FutureLink_deleteEmployeeAbsencesInMSBC extends FutureLink {
	Set<Id> oldAbsencesIds;

  public FutureLink_deleteEmployeeAbsencesInMSBC(){
    super();
  }

	public FutureLink_deleteEmployeeAbsencesInMSBC(Set<Id> oldAbsencesIds) {
		super();
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
    Logger.info('MSBCAPI.DeleteEmployeeAbsencesRequestParams records').setMessage(JSON.serialize(deleteEmployeeList));
    Logger.saveLog();

    for(MSBCAPI.DeleteEmployeeAbsencesRequestParams params : deleteEmployeeList){
      MSBCAPI.deleteEmployeeAbsences(params.companyId, params.absenceDayId);
    }
	}
}
  