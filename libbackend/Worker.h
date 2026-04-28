#pragma once

#include "Job.h"
#include <string>
#include <cstdlib>

class Worker {
public:
    static JobResult execute(const Job& job) {
        // std::string cmd = "luajit -l import/init " + job.script;
        std::string cmd = "luajit -l import/init " + std::string("'") + job.script + "'";

        int code = std::system(cmd.c_str());

        return JobResult{
            .success = (code == 0),
            .exitCode = code
        };
    }
};