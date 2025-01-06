public with sharing class TimeEntries_ScheduleBatch implements Database.Batchable<MSBCAPI.Header> , Database.Stateful , Database.AllowsCallouts , Schedulable { 
    Integer numberOfHeaders = 0;
    public Iterable<MSBCAPI.Header> start(Database.BatchableContext info){
        return new MSBCAPI_HeaderIterable();
    }

    public void execute(Database.BatchableContext info, List<MSBCAPI.Header> scope){
        List<flair__Time_Entry__c> timeEntries = new List<flair__Time_Entry__c>();
        Set<String> ERP_ResourceNumbers = new Set<String>();
        for(MSBCAPI.Header header : scope){
            ERP_ResourceNumbers.add(header.resNo);
        }
        System.debug('scope : '+ scope);
        Map<String, Id> employeeMap = new Map<String, Id>();
        for(flair__Employee__c employee : [SELECT Id, ERP_Resource_No__c FROM flair__Employee__c WHERE ERP_Resource_No__c IN :ERP_ResourceNumbers]){
            employeeMap.put(employee.ERP_Resource_No__c, employee.Id);
        }
        System.debug('employeeMap : ' + employeeMap);
        for(MSBCAPI.Header header : scope){
            flair__Time_Entry__c timeEntry = new flair__Time_Entry__c();
            timeEntry.flair__Employee__c = employeeMap.get(header.resNo);
            timeEntry.flair__Migration_ID__c = header.id;
            timeEntry.flair__Start_Datetime__c = Datetime.valueOf(header.xdate + ' ' + header.fromTime);
            timeEntry.flair__End_Datetime__c =  Datetime.valueOf(header.xdate + ' ' + header.toTime);
            timeEntry.flair__Approval_Status__c = 'PENDING';
            timeEntries.add(timeEntry);
        }
        numberOfHeaders += scope.size();
        upsert timeEntries flair__Migration_ID__c;
    }

    public void finish(Database.BatchableContext info){
        System.debug('Number of Headers processed: ' + numberOfHeaders);
    }

    public  void execute(SchedulableContext sc) {
        Database.executeBatch(new TimeEntries_ScheduleBatch());
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
}