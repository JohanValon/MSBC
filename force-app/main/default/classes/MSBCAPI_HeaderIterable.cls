public with sharing class MSBCAPI_HeaderIterable implements Iterable<MSBCAPI.Header> {
    // Resigner les flair__Migration_ID__c manuellement dans les entités
    // Lister l'ensemble des noms des entités gérés dans l'intégration et les passer en paramètre dans la requête çi dessous (Stoker dans un Custom Metadata Type)
    // On peut aussi y stocker les flair__Migration_ID__c
    public Iterator<MSBCAPI.Header> iterator() {
        List<MSBCAPI.Header> headers = new List<MSBCAPI.Header>();
        for (flair__Entity__c entry : [SELECT flair__Migration_ID__c FROM flair__Entity__c WHERE Name = 'Con4Mare GmbH & Cie. KG']) { 
            headers.addAll(MSBCAPI.getHeaders(entry.flair__Migration_ID__c).value);
        }
        System.debug('headers' + headers);
        return new MSBCAPI_HeaderIterator(headers);
    }

}