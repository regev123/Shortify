package com.shortify.stats.config;

import org.apache.kafka.clients.admin.AdminClientConfig;
import org.apache.kafka.clients.consumer.ConsumerConfig;
import org.apache.kafka.common.serialization.StringDeserializer;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.kafka.config.ConcurrentKafkaListenerContainerFactory;
import org.springframework.kafka.config.TopicBuilder;
import org.springframework.kafka.core.ConsumerFactory;
import org.springframework.kafka.core.DefaultKafkaConsumerFactory;
import org.springframework.kafka.core.KafkaAdmin;
import org.springframework.kafka.listener.ContainerProperties;
import org.springframework.kafka.support.serializer.JsonDeserializer;

import java.util.HashMap;
import java.util.Map;

@Configuration
public class KafkaConfig {
    
    @Value("${spring.kafka.bootstrap-servers:localhost:9092}")
    private String bootstrapServers;
    
    @Value("${spring.kafka.consumer.group-id:stats-service-group}")
    private String groupId;
    
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
    public ConsumerFactory<String, Object> consumerFactory() {
        Map<String, Object> configProps = new HashMap<>();
        configProps.put(ConsumerConfig.BOOTSTRAP_SERVERS_CONFIG, bootstrapServers);
        configProps.put(ConsumerConfig.GROUP_ID_CONFIG, groupId);
        configProps.put(ConsumerConfig.KEY_DESERIALIZER_CLASS_CONFIG, StringDeserializer.class);
        configProps.put(ConsumerConfig.VALUE_DESERIALIZER_CLASS_CONFIG, JsonDeserializer.class);
        configProps.put(JsonDeserializer.TRUSTED_PACKAGES, "*");
        configProps.put(ConsumerConfig.AUTO_OFFSET_RESET_CONFIG, "earliest"); // Read from beginning if no offset
        configProps.put(ConsumerConfig.ENABLE_AUTO_COMMIT_CONFIG, false); // Manual commit for reliability
        return new DefaultKafkaConsumerFactory<>(configProps);
    }
    
    @Bean
    public ConcurrentKafkaListenerContainerFactory<String, Object> kafkaListenerContainerFactory() {
        ConcurrentKafkaListenerContainerFactory<String, Object> factory = 
                new ConcurrentKafkaListenerContainerFactory<>();
        factory.setConsumerFactory(consumerFactory());
        factory.getContainerProperties().setAckMode(ContainerProperties.AckMode.MANUAL_IMMEDIATE);
        // Enable batch processing for high throughput
        factory.setBatchListener(true);
        // Increase concurrency for parallel processing (1 thread per partition)
        factory.setConcurrency(3); // Adjust based on Kafka topic partitions
        return factory;
    }
}

