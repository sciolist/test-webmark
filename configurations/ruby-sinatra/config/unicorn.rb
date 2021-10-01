require 'etc'
worker_processes (Etc.nprocessors*2)
timeout 30
preload_app true
