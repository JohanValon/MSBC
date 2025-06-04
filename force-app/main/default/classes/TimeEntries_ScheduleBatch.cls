public with sharing class TimeEntries_ScheduleBatch implements Database.Batchable<MSBCAPI.Header> , Database.Stateful , Database.AllowsCallouts , Schedulable { 
  Integer numberOfHeaders = 0;
  private String originalTransactionId;
  private static String INTEGRATION_USER = MSBC_API_Configuration__mdt.getInstance('Production').Integration_User_Username__c	;

  public Iterable<MSBCAPI.Header> start(Database.BatchableContext info){
    this.originalTransactionId = Nebula.Logger.getTransactionId();

    Nebula.Logger.info('Starting TimeEntries_ScheduleBatch');
    Nebula.Logger.saveLog();
  
    return new MSBCAPI_HeaderIterable();
  }

  public void execute(Database.BatchableContext info, MSBCAPI.Header[] scope){
    Nebula.Logger.setParentLogTransactionId(this.originalTransactionId);

		flair__Time_Entry__c[] timeEntries = new List<flair__Time_Entry__c>();
    Set<String> ERP_ResourceNumbers = new Set<String>();
    Map<String, Decimal> breakTimesByHeaderIds = new Map<String, Decimal>();
    Set<String> headerIds = new Set<String>();
    for(MSBCAPI.Header header : scope){
      ERP_ResourceNumbers.add(header.resNo);
      headerIds.add(header.id);
    }

    Map<String, Id> employeeMap = new Map<String, Id>();
    for(flair__Employee__c employee : [SELECT Id, Company_Personnel_Number__c FROM flair__Employee__c WHERE Company_Personnel_Number__c IN :ERP_ResourceNumbers]){
      employeeMap.put(employee.Company_Personnel_Number__c, employee.Id);
    }

    String integrationUserId = [SELECT Id FROM User WHERE UserName = :INTEGRATION_USER LIMIT 1]?.Id;

    String[] headerIdsNotToUpsert = new String[]{};
    if(integrationUserId != null){
      for(flair__Time_Entry__c timeEntry : [SELECT LastModifiedById, flair__Migration_ID__c FROM flair__Time_Entry__c WHERE flair__Migration_ID__c IN :headerIds AND LastModifiedById != :integrationUserId]){
        headerIdsNotToUpsert.add(timeEntry.flair__Migration_ID__c);
      }
    }

    Nebula.Logger.info('Processed headerIdsNotToUpsert').setMessage(JSON.serialize(headerIdsNotToUpsert));
    
    // Check for Time Entries that are in MSBC but not in Salesforce and mark them for deletion if they are not in the current batch 
    flair__Time_Entry__c[] timeEntriesToDelete = new List<flair__Time_Entry__c>();
    for(flair__Time_Entry__c  timeEntry : [SELECT Id, To_Delete__c FROM flair__Time_Entry__c WHERE flair__Employee__c IN :employeeMap.values() 
      AND flair__Start_Datetime__c >= :DateTime.newInstance(System.today().addMonths(-2).toStartOfMonth(), Time.newInstance(0,0,0,0)) 
      AND flair__Approval_Status__c = 'APPROVED' AND flair__Migration_ID__c NOT IN :headerIds AND To_Delete__c = false AND LastModifiedById = :integrationUserId]){
      timeEntry.To_Delete__c = true;
      timeEntriesToDelete.add(timeEntry);
    }

    for(MSBCAPI.Header header : scope){
      if(!headerIdsNotToUpsert.contains(header.id) && employeeMap.get(header.resNo) != null){
        flair__Time_Entry__c newTimeEntry = new flair__Time_Entry__c();
        newTimeEntry.flair__Employee__c = employeeMap.get(header.resNo);
        newTimeEntry.flair__Migration_ID__c = header.id;
        newTimeEntry.flair__Start_Datetime__c = Datetime.valueOf(header.xdate + ' ' + header.fromTime);
        newTimeEntry.flair__End_Datetime__c =  Datetime.valueOf(header.xdate + ' ' + header.toTime);
        newTimeEntry.odata_etag__c = header.odataEtag;
        newTimeEntry.shoringModelCode__c = header.shoringModelCode == 'OFFSHORE' ? 'OFFSHORE' : '';
        newTimeEntry.flair__Approval_Status__c = 'APPROVED';
        timeEntries.add(newTimeEntry);
        breakTimesByHeaderIds.put(header.id, header.breakTime);
      }
    }

    numberOfHeaders += scope.size();
    Database.UpsertResult[] timeEntriesResults = Database.upsert(timeEntries, flair__Time_Entry__c.flair__Migration_ID__c, true, AccessLevel.SYSTEM_MODE);
    Nebula.Logger.info('Processed time entry records', timeEntriesResults);

		flair__Time_Entry_Break__c[] timeBreaks = new List<flair__Time_Entry_Break__c>();
    for(flair__Time_Entry__c  timeEntry : [SELECT Id, flair__Start_Datetime__c, flair__Migration_ID__c FROM flair__Time_Entry__c WHERE flair__Migration_ID__c IN :breakTimesByHeaderIds.keySet()]){
      flair__Time_Entry_Break__c timeBreak = new flair__Time_Entry_Break__c();
      timeBreak.flair__Time_Entry__c = timeEntry.Id;
      timeBreak.flair__Migration_ID__c = timeEntry.flair__Migration_ID__c;
      timeBreak.flair__Start_Datetime__c = timeEntry.flair__Start_Datetime__c;
      timeBreak.flair__End_Datetime__c = timeEntry.flair__Start_Datetime__c.addMinutes((breakTimesByHeaderIds.get(timeEntry.flair__Migration_ID__c) * 60 ).intValue());
      timeBreaks.add(timeBreak);
    }
    
    Database.UpsertResult[] timeBreaksResults = Database.upsert(timeBreaks, flair__Time_Entry_Break__c.flair__Migration_ID__c, true, AccessLevel.SYSTEM_MODE);
    Nebula.Logger.info('Processed time entry break records', timeBreaksResults);

    Map<String, flair__Time_Entry__c> timeEntriesProcessedMap = new Map<String, flair__Time_Entry__c>();
    for(flair__Time_Entry__c  timeEntry : [SELECT Id, flair__Start_Datetime__c, flair__Employee__r.Company_Personnel_Number__c, CreatedDate FROM flair__Time_Entry__c WHERE flair__Employee__c IN :employeeMap.values() AND flair__Approval_Status__c = 'APPROVED']) {
      String key = timeEntry.flair__Employee__r.Company_Personnel_Number__c + timeEntry.flair__Start_Datetime__c.format('yyyy-MM-dd');
      if (!timeEntriesProcessedMap.containsKey(key)) {
        timeEntriesProcessedMap.put(key, timeEntry);
      } else {
        if(timeEntriesProcessedMap.get(key).CreatedDate <= timeEntry.CreatedDate) {
          timeEntriesProcessedMap.get(key).To_Delete__c = true;
          timeEntriesToDelete.add(timeEntriesProcessedMap.get(key));
          timeEntriesProcessedMap.put(key, timeEntry);
        } else {
          timeEntry.To_Delete__c = true;
          timeEntriesToDelete.add(timeEntry);
        }
      }
    }

    Nebula.Logger.info('Kept time entries', timeEntriesProcessedMap.values());
    Database.SaveResult[] timeEntryDeleteResults = Database.update(timeEntriesToDelete, true, AccessLevel.SYSTEM_MODE);
    Nebula.Logger.info('Time entry records Marked to delete', timeEntryDeleteResults);
    Nebula.Logger.saveLog();
  }

  public void finish(Database.BatchableContext info){
    Nebula.Logger.info('Number of Headers processed: ' + numberOfHeaders);
    Nebula.Logger.setParentLogTransactionId(this.originalTransactionId);
    Nebula.Logger.info('Finishing running TimeEntries_ScheduleBatch');
    Nebula.Logger.saveLog();
  }

  public void execute(SchedulableContext sc) {
    Database.executeBatch(new TimeEntries_ScheduleBatch(), 100);
  }

  public static void start(){
    String jobName = 'TimeEntries_ScheduleBatch' + ' - ' + Datetime.now().format();
    String cron = '0 0 1 ? * *'; //Every day at 1:AM hour
		Nebula.Logger.info('Scheduling TimeEntries_ScheduleBatch with cron: ' + cron);
    System.schedule(jobName, cron, new TimeEntries_ScheduleBatch());
  }
}