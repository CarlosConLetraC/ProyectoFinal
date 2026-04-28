#pragma once

#include "Job.h"
#include "ThreadPool.h"
#include "Worker.h"

#include <queue>
#include <vector>
#include <mutex>
#include <thread>
#include <atomic>
#include <iostream>
#include <chrono>

static std::mutex cout_mtx;

#define SAFE_COUT(x) \
    do { std::lock_guard<std::mutex> lock(cout_mtx); std::cout << x << std::endl; } while(0)

class Scheduler {
private:
    ThreadPool pool;

    std::queue<Job> pending;
    std::vector<Job> delayed;

    std::mutex mtx;
    std::atomic<bool> stop{false};

    std::thread dispatcherThread;

    struct Compare {
        bool operator()(const Job& a, const Job& b) {
            return a.priority < b.priority;
        }
    };

    std::priority_queue<Job, std::vector<Job>, Compare> ready;

public:
    explicit Scheduler(size_t threads) : pool(threads) {}
    void start() {
        dispatcherThread = std::thread([this] {
            runDispatcher();
        });
    }

    void stopScheduler() {
        stop = true;
        if (dispatcherThread.joinable()) dispatcherThread.join();
    }

    void submit(Job job) {
        std::lock_guard<std::mutex> lock(mtx);
        pending.push(std::move(job));
    }

private:
    void runDispatcher() {
        while (!stop) {
            movePendingToReady();
            moveDelayedToReady();
            dispatchReady();

            std::this_thread::sleep_for(std::chrono::milliseconds(20));
        }
    }

    void movePendingToReady() {
        std::lock_guard<std::mutex> lock(mtx);

        while (!pending.empty()) {
            ready.push(std::move(pending.front()));
            pending.pop();
        }
    }

    void moveDelayedToReady() {
        std::lock_guard<std::mutex> lock(mtx);

        auto now = std::chrono::steady_clock::now();

        auto it = delayed.begin();
        while (it != delayed.end()) {
            if (it->runAt <= now) {
                ready.push(*it);
                it = delayed.erase(it);
            } else {
                ++it;
            }
        }
    }

    void dispatchReady() {
        std::lock_guard<std::mutex> lock(mtx);

        while (!ready.empty()) {
            Job job = std::move(ready.top());
            ready.pop();

            pool.enqueue([this, job]() mutable {
                executeJob(std::move(job));
            });
        }
    }

    void executeJob(Job job) {
        job.status = JobStatus::RUNNING;

        SAFE_COUT("[Job " << job.id << "] RUN " << job.script);

        JobResult result = Worker::execute(job);

        if (result.success) {
            job.status = JobStatus::SUCCESS;
            SAFE_COUT("[Job " << job.id << "] SUCCESS");
            return;
        }

        job.status = JobStatus::FAILED;

        if (job.retries < job.maxRetries) {
            job.retries++;
            job.status = JobStatus::RETRYING;
            job.runAt = std::chrono::steady_clock::now() + std::chrono::milliseconds(500);

            std::lock_guard<std::mutex> lock(mtx);
            delayed.push_back(std::move(job));

            SAFE_COUT("[Job " << job.id << "] RETRY " << job.retries);
        }
    }
};