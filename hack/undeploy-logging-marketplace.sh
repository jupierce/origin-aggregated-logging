#!/bin/bash

wait_for_condition()
{
    # $1 is shell function condition to execute until it returns success
    # $2 is the timeout number of retries - default 60
    # $3 is the interval in seconds - default 1
    # e.g. the total timeout in seconds is timeout * interval
    local cmd=$1
    local timeout=${2:-60}
    local interval=${3:-1}
    local ii=0
    for ii in $( seq 1 $timeout ) ; do
        if $cmd ; then
            break
        fi
        sleep $interval
    done
    if [ $ii = $timeout ] ; then
        return 1
    fi
    return 0
}

set -euxo pipefail

oc delete project openshift-logging || :
wait_func() { ! oc get project openshift-logging > /dev/null 2>&1 ; }
wait_for_condition wait_func 600 10

oc -n openshift-marketplace delete CatalogSourceConfig cluster-logging || :
wait_func() { ! oc -n openshift-marketplace get CatalogSourceConfig cluster-logging > /dev/null 2>&1 ; }
wait_for_condition wait_func 600 10

for sub in $( oc -n openshift-operators get subscriptions -o name | grep elasticsearch ) ; do
    oc -n openshift-operators delete $sub || :
    wait_func() { ! oc -n openshift-operators get $sub > /dev/null 2>&1 ; }
    wait_for_condition wait_func 600 10
done

oc get clusterserviceversions --all-namespaces | \
    awk '/elasticsearch-operator/ {print $1, $2}' | \
    while read ns csv ; do
        oc -n $ns delete clusterserviceversions $csv
    done

oc -n openshift-operators delete deploy elasticsearch-operator || :

oc -n openshift-marketplace delete CatalogSourceConfig elasticsearch || :
wait_func() { ! oc -n openshift-marketplace get CatalogSourceConfig elasticsearch > /dev/null 2>&1 ; }
wait_for_condition wait_func 600 10

oc -n openshift-operator-lifecycle-manager scale --replicas=1 deploy/olm-operator || :
wait_func() { oc -n openshift-operator-lifecycle-manager get pods | grep -q '^olm-operator-.*Running' ; }
wait_for_condition wait_func 600 10
