# frozen_string_literal: true

require 'dfe/analytics/shared/service_pattern'

require 'dfe/analytics/services/apply_airbyte_final_tables_policy_tags'
require 'dfe/analytics/services/apply_airbyte_internal_tables_policy_tags'
require 'dfe/analytics/services/checksum_calculator'
require 'dfe/analytics/services/entity_table_checks'
require 'dfe/analytics/services/generic_checksum_calculator'
require 'dfe/analytics/services/postgres_checksum_calculator'
require 'dfe/analytics/services/wait_for_migrations'
