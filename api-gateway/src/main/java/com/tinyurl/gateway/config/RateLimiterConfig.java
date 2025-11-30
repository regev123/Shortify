package com.tinyurl.gateway.config;

import com.tinyurl.gateway.util.IpAddressExtractor;
import org.springframework.cloud.gateway.filter.ratelimit.KeyResolver;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.server.ServerWebExchange;
import reactor.core.publisher.Mono;

/**
 * Rate Limiter Configuration
 * 
 * Configures rate limiting based on client IP address.
 * 
 * This bean is REQUIRED by application.yml which references it:
 * key-resolver: "#{@ipKeyResolver}"
 * 
 * The custom implementation handles proxy headers (X-Forwarded-For, X-Real-IP)
 * which is important when the gateway is behind a load balancer.
 */
@Configuration
public class RateLimiterConfig {
    
    /**
     * IP-based key resolver for rate limiting
     * Limits requests per IP address
     * 
     * This bean cannot be removed - it's referenced in application.yml
     */
    @Bean
    public KeyResolver ipKeyResolver() {
        return exchange -> {
            String clientIp = IpAddressExtractor.extractIp(exchange);
            return Mono.just(clientIp);
        };
    }
}

