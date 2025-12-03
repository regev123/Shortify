package com.shortify.lookup.config;

import org.apache.kafka.clients.admin.AdminClientConfig;
import org.apache.kafka.clients.producer.ProducerConfig;
import org.apache.kafka.common.serialization.StringSerializer;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.kafka.config.TopicBuilder;
import org.springframework.kafka.core.DefaultKafkaProducerFactory;
import org.springframework.kafka.core.KafkaAdmin;
import org.springframework.kafka.core.KafkaTemplate;
import org.springframework.kafka.core.ProducerFactory;
import org.springframework.kafka.support.serializer.JsonSerializer;

import java.util.HashMap;
import java.util.Map;

@Configuration
public class KafkaConfig {
    
    @Value("${spring.kafka.bootstrap-servers:localhost:9092}")
    private String bootstrapServers;
    
    @Value("${kafka.topic.click-events:url-click-events}")
    private String clickEventsTopic;
    
    @Value("${kafka.topic.url-deleted:url-deleted-events}")
    private String urlDeletedTopic;
    
    /**
     * KafkaAdmin bean enables automatic topic creation
     * Topics will be created when the application starts if they don't exist
     */
    @Bean
    public KafkaAdmin kafkaAdmin() {
        Map<String, Object> configs = new HashMap<>();
        configs.put(AdminClientConfig.BOOTSTRAP_SERVERS_CONFIG, bootstrapServers);
        return new KafkaAdmin(configs);
    }
    
    /**
     * Auto-create url-click-events topic with production-ready configuration
     * 6 partitions for parallel processing, replication factor 3 for high availability
     */
    @Bean
    public org.apache.kafka.clients.admin.NewTopic clickEventsTopic() {
        return TopicBuilder.name(clickEventsTopic)
                .partitions(6)
                .replicas(3)
                .build();
    }
    
    /**
     * Auto-create url-deleted-events topic with production-ready configuration
     * 6 partitions for parallel processing, replication factor 3 for high availability
     */
    @Bean
    public org.apache.kafka.clients.admin.NewTopic urlDeletedTopic() {
        return TopicBuilder.name(urlDeletedTopic)
                .partitions(6)
                .replicas(3)
                .build();
    }
    
    @Bean
    public ProducerFactory<String, Object> producerFactory() {
        Map<String, Object> configProps = new HashMap<>();
        configProps.put(ProducerConfig.BOOTSTRAP_SERVERS_CONFIG, bootstrapServers);
        configProps.put(ProducerConfig.KEY_SERIALIZER_CLASS_CONFIG, StringSerializer.class);
        configProps.put(ProducerConfig.VALUE_SERIALIZER_CLASS_CONFIG, JsonSerializer.class);
        configProps.put(ProducerConfig.ACKS_CONFIG, "all"); // Wait for all in-sync replicas (required for idempotence)
        configProps.put(ProducerConfig.RETRIES_CONFIG, 3);
        configProps.put(ProducerConfig.ENABLE_IDEMPOTENCE_CONFIG, true);
        return new DefaultKafkaProducerFactory<>(configProps);
    }
    
    @Bean
    public KafkaTemplate<String, Object> kafkaTemplate() {
        return new KafkaTemplate<>(producerFactory());
    }
}

