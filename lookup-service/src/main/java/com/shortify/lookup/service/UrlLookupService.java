package com.shortify.lookup.service;

import com.shortify.lookup.dto.UrlLookupResult;
import com.shortify.lookup.exception.UrlExpiredException;
import com.shortify.lookup.exception.UrlNotFoundException;

/**
 * Interface for URL lookup operations
 * Part of the Lookup Service microservice
 * 
 * Follows Interface Segregation Principle - focused on lookup operations only
 */
public interface UrlLookupService {
    
    /**
     * Gets the original URL for a given short code
     * 
     * @param shortCode the short code to look up
     * @return the original URL
     * @throws UrlNotFoundException if short URL not found
     * @throws UrlExpiredException if short URL has expired
     */
    String getOriginalUrl(String shortCode);
    
    /**
     * Looks up a short URL and returns lookup result
     * 
     * @param shortCode the short code to look up
     * @return lookup result with original URL
     */
    UrlLookupResult lookupUrl(String shortCode);
}

