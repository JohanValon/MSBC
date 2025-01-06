public with sharing class MSBCAPI_HeaderIterator implements Iterator<MSBCAPI.Header> {

    private List<MSBCAPI.Header> headers;
    private Integer currentIndex;
  
    public MSBCAPI_HeaderIterator(List<MSBCAPI.Header> headers){
        this.headers = headers;
        this.currentIndex = 0;
    }
  
    public Boolean hasNext(){ 
        return currentIndex < headers.size();
    }    
  
    public MSBCAPI.Header next(){
        if(hasNext()) {
            return headers[currentIndex++];
        } else {
            throw new NoSuchElementException('Iterator has no more elements.');
        }
    } 
}