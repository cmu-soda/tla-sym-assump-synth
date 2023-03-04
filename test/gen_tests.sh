#!/bin/sh

rob="/Users/idardik/Documents/CMU/tlaplus-master/git/tlaplus/test/robustness.py"
test_dir_coff="/Users/idardik/Documents/CMU/tlaplus-master/git/tlaplus/test/coffee_tea/"
test_dir_voting="/Users/idardik/Documents/CMU/tlaplus-master/git/tlaplus/test/voting/"
test_dir_therac="/Users/idardik/Documents/CMU/tlaplus-master/git/tlaplus/test/therac25/"
test_dir_fixed_mutex="/Users/idardik/Documents/CMU/tlaplus-master/git/tlaplus/test/fixed_mutex/"

gen_test_suite() {
    pushd "${1}"
    shift
    files="${@}"
    mkdir -p expected/
    for name in ${files[@]}
    do
        # gen robustness
        tla_file="${name}.tla"
        expected_file="expected/${name}.txt"
        echo "writing ${expected_file}"
        python3 "${rob}" --cleanup --outdir out --spec "${tla_file}" > "${expected_file}"

        # gen comparison
        for name2 in ${files[@]}
        do
            if [[ "${name}" != "${name2}" ]]
            then
                tla_file2="${name2}.tla"
                expected_file2="expected/${name}_${name2}.txt"
                echo "writing ${expected_file2}"
                python3 "${rob}" --cleanup --outdir out --spec "${tla_file}" --spec2 "${tla_file2}" --compare > "${expected_file2}"
            fi
        done
    done
}


coff_tests=("CoffeeTeaSmall" "CoffeeTeaSmallPrime" "CoffeeTeaSmallBad" "CoffeeTeaSmallCorrect")
gen_test_suite "${test_dir_coff}" "${coff_tests[@]}"

voting_tests=("Voting" "VotingEOCannotCfm" "SecureVoting")
gen_test_suite "${test_dir_voting}" "${voting_tests[@]}"

therac_tests=("Therac25" "Therac20")
gen_test_suite "${test_dir_therac}" "${therac_tests[@]}"

fixed_mutex_tests=("MutexExample")
gen_test_suite "${test_dir_fixed_mutex}" "${fixed_mutex_tests[@]}"
