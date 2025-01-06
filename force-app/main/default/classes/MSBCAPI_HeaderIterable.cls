public with sharing class MSBCAPI_HeaderIterable implements Iterable<MSBCAPI.Header> {
    public Iterator<MSBCAPI.Header> iterator() {
        return new MSBCAPI_HeaderIterator(MSBCAPI.getHeaders().value);
    }
}