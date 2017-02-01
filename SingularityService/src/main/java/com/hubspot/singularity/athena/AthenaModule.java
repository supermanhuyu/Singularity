package com.hubspot.singularity.athena;

import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

import com.google.common.base.Optional;
import com.google.inject.AbstractModule;
import com.google.inject.Provides;
import com.google.inject.Scopes;
import com.google.inject.Singleton;
import com.google.inject.name.Named;
import com.hubspot.singularity.config.AthenaConfig;
import com.hubspot.singularity.config.SingularityConfiguration;

public class AthenaModule extends AbstractModule {

  private final Optional<AthenaConfig> config;
  public static final String ATHENA_QUERY_EXECUTOR = "athena.query.executor";

  public AthenaModule(Optional<AthenaConfig> config) {
    this.config = config;
  }

  @Override
  public void configure() {
    if (config.isPresent()) {
      try {
        Class.forName("com.amazonaws.athena.jdbc.AthenaDriver");
      } catch (ClassNotFoundException cnfe) {
        throw new RuntimeException("Could not locate Athena driver class");
      }
      bind(AthenaQueryRunner.class).to(JDBCAthenaQueryRunner.class).in(Scopes.SINGLETON);
    } else {
      bind(AthenaQueryRunner.class).to(NoopAthenaQueryRunner.class).in(Scopes.SINGLETON);
    }
  }

  @Provides
  @Singleton
  @Named(ATHENA_QUERY_EXECUTOR)
  public ExecutorService providesQueryExecutor() {
    return Executors.newFixedThreadPool(1);
  }

  @Provides
  @Singleton
  public Optional<AthenaConfig> providesAthenaConfig(SingularityConfiguration configuration) {
    return configuration.getAthenaConfig();
  }
}
