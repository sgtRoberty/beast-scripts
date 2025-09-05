#!/bin/bash

# Usage message
usage() {
    echo "Usage: $0 input.csv > output.csv"
    exit 1
}

# Show usage if no input or help is requested
if [[ $# -ne 1 || "$1" == "-h" || "$1" == "--help" ]]; then
    usage
fi

awk -F, '
NR==1 {
    # Find indexes of needed columns
    for(i=1; i<=NF; i++) {
        header[i]=$i
    }
    for(i=1; i<=NF; i++) {
        if(header[i]=="filename") fidx=i
        else if(header[i]=="step") sidx=i
        else if(header[i]=="likelihood") lidx=i
        else if(header[i]=="ESS") eidx=i
        else if(header[i]=="contribution") cidx=i
        else if(header[i]=="sum_ESS") seidx=i
        else if(header[i]=="marginal_L_estimate") mlidx=i
    }
    next
}
{
    filename=$fidx
    step=$sidx+0  # ensure numeric

    # Store likelihood, ESS, contribution per run-step
    likelihood[filename,step] = $lidx
    ESS[filename,step] = $eidx
    contribution[filename,step] = $cidx

    # Store sum_ESS and marginal_L_estimate once per run (step 0)
    if(step == 0) {
        sumESS[filename] = $seidx
        marginalL[filename] = $mlidx
    }

    # Track filenames and max step for building header/output
    if(!(filename in filenames)) {
        filenames[filename] = 1
        filenames_list[++fcount] = filename
    }
    if(step > maxstep) maxstep = step
}
END {
    # Print header line
    printf "filename"
    for(s=0; s<=maxstep; s++) {
        printf ",likelihood_step%d,ESS_step%d,contribution_step%d", s,s,s
    }
    printf ",sum_ESS,marginal_L_estimate\n"

    # Print each filenames data row
    for(fi=1; fi<=fcount; fi++) {
        fname = filenames_list[fi]
        printf "%s", fname
        for(s=0; s<=maxstep; s++) {
            printf ",%s,%s,%s",
                ((fname,s) in likelihood) ? likelihood[fname,s] : "",
                ((fname,s) in ESS) ? ESS[fname,s] : "",
                ((fname,s) in contribution) ? contribution[fname,s] : ""
        }
        printf ",%s,%s\n",
            (fname in sumESS) ? sumESS[fname] : "",
            (fname in marginalL) ? marginalL[fname] : ""
    }
}
' "$1"
