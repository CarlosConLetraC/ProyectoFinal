#pragma once

#include "Job.h"
#include <queue>
#include <mutex>

class Broker {
private:
    std::queue<Job> q;
    std::mutex mtx;

public:
    void push(Job job) {
        std::lock_guard<std::mutex> lock(mtx);
        q.push(job);
    }

    bool pop(Job& job) {
        std::lock_guard<std::mutex> lock(mtx);

        if (q.empty()) return false;
        job = q.front();
        q.pop();
        return true;
    }

    bool empty() {
        std::lock_guard<std::mutex> lock(mtx);
        return q.empty();
    }
};