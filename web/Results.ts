import path from "path";
import { observable } from "iaktta.preact";

export const appState = observable({
  selectedTest: ""
});

const ctx = require.context(process.env.DIRECTORY, true, /\.json$/);
export let results: Configuration = {};
ctx.keys().forEach(k => {
  const testName = path.basename(path.dirname(k));
  if (testName === '.') return;
  const cfgName = path.basename(k, ".json");
  const data = ctx(k);
  if (!appState.selectedTest) {
    appState.selectedTest = testName;
  }
  if (!results[cfgName]) results[cfgName] = { tests: {} };
  results[cfgName].tests[testName] = data;
});

export interface Configuration {
  [key: string]: {
    tests: { [key: string]: TestInfo };
  };
}

export interface TestInfo {
  url: string;
  requests: Requests;
  latency: Latency;
  throughput: Throughput;
  errors: number;
  timeouts: number;
  duration: number;
  start: string;
  finish: string;
  connections: number;
  pipelining: number;
  non2xx: number;
  "1xx": number;
  "2xx": number;
  "3xx": number;
  "4xx": number;
  "5xx": number;
  mem_usage: number;
  samples: DockerSample[];
}

export interface Requests {
  average: number;
  mean: number;
  stddev: number;
  min: number;
  max: number;
  total: number;
  p0_001: number;
  p0_01: number;
  p0_1: number;
  p1: number;
  p2_5: number;
  p10: number;
  p25: number;
  p50: number;
  p75: number;
  p90: number;
  p97_5: number;
  p99: number;
  p99_9: number;
  p99_99: number;
  p99_999: number;
  sent: number;
}

export interface Latency {
  average: number;
  mean: number;
  stddev: number;
  min: number;
  max: number;
  p0_001: number;
  p0_01: number;
  p0_1: number;
  p1: number;
  p2_5: number;
  p10: number;
  p25: number;
  p50: number;
  p75: number;
  p90: number;
  p97_5: number;
  p99: number;
  p99_9: number;
  p99_99: number;
  p99_999: number;
}

export interface Throughput {
  average: number;
  mean: number;
  stddev: number;
  min: number;
  max: number;
  total: number;
  p0_001: number;
  p0_01: number;
  p0_1: number;
  p1: number;
  p2_5: number;
  p10: number;
  p25: number;
  p50: number;
  p75: number;
  p90: number;
  p97_5: number;
  p99: number;
  p99_9: number;
  p99_99: number;
  p99_999: number;
}

export interface DockerSample {
  read: string;
  preread: string;
  pids_stats: {
    current: number;
  };
  blkio_stats: {
    io_service_bytes_recursive: [];
    io_serviced_recursive: [];
    io_queue_recursive: [];
    io_service_time_recursive: [];
    io_wait_time_recursive: [];
    io_merged_recursive: [];
    io_time_recursive: [];
    sectors_recursive: [];
  };
  num_procs: number;
  storage_stats: {};
  cpu_stats: {
    cpu_usage: {
      total_usage: number;
      percpu_usage: number[];
      usage_in_kernelmode: number;
      usage_in_usermode: number;
    };
    system_cpu_usage: number;
    online_cpus: number;
    throttling_data: {
      periods: number;
      throttled_periods: number;
      throttled_time: number;
    };
  };
  precpu_stats: {
    cpu_usage: {
      total_usage: number;
      percpu_usage: number[];
      usage_in_kernelmode: number;
      usage_in_usermode: number;
    };
    system_cpu_usage: number;
    online_cpus: number;
    throttling_data: {
      periods: number;
      throttled_periods: number;
      throttled_time: number;
    };
  };
  memory_stats: {
    usage: number;
    max_usage: number;
    stats: {
      active_anon: number;
      active_file: number;
      cache: number;
      dirty: number;
      hierarchical_memory_limit: number;
      hierarchical_memsw_limit: number;
      inactive_anon: number;
      inactive_file: number;
      mapped_file: number;
      pgfault: number;
      pgmajfault: number;
      pgpgin: number;
      pgpgout: number;
      rss: number;
      rss_huge: number;
      total_active_anon: number;
      total_active_file: number;
      total_cache: number;
      total_dirty: number;
      total_inactive_anon: number;
      total_inactive_file: number;
      total_mapped_file: number;
      total_pgfault: number;
      total_pgmajfault: number;
      total_pgpgin: number;
      total_pgpgout: number;
      total_rss: number;
      total_rss_huge: number;
      total_unevictable: number;
      total_writeback: number;
      unevictable: number;
      writeback: number;
    };
    limit: number;
  };
  name: string;
  id: string;
  networks: {
    eth0: {
      rx_bytes: number;
      rx_packets: number;
      rx_errors: number;
      rx_dropped: number;
      tx_bytes: number;
      tx_packets: number;
      tx_errors: number;
      tx_dropped: number;
    };
  };
}
