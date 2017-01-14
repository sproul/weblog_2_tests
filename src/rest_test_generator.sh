#!/bin/bash
export PATH=`dirname $0`:$PATH
echo "ruby -wS rest_test_generator.rb $*"
ruby       -wS rest_test_generator.rb $*

exit
# example
$dp/rest_test_generator/weblog_2_tests/src/rest_test_generator.sh -suppress_string 'e=prod&m=true&p=true&' -server_url http://slcipau/configuration/api -generated_tests_dir /net/slcipaq/scratch/pau_logs_selection/tests/v1_orchestrations_L1_products_DTE_WEBCENTER_GENERIC_12_2_1_3_9_summary -execute
