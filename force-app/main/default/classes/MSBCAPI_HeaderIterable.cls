public with sharing class MSBCAPI_HeaderIterable implements Iterable<MSBCAPI.Header> {
    public Iterator<MSBCAPI.Header> iterator() {
        List<MSBCAPI.Header> headers = new List<MSBCAPI.Header>();
        for (flair__Entity__c entry : [SELECT flair__Migration_ID__c FROM flair__Entity__c WHERE Is_MSBC_Synched__c = true]) { 
            headers.addAll(MSBCAPI.getHeaders(entry.flair__Migration_ID__c).value);
        }
        Nebula.Logger.info('retreived headers').setMessage(JSON.serialize(headers));
        return new MSBCAPI_HeaderIterator(headers);
    }
}