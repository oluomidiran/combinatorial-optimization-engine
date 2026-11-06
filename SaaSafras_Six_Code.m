% SaaSafras_Six_Code.m
% Brute-force search over 6-month team allocations (4 decision blocks, 231
% allocations per block, 231^4 = 2.85 billion strategies) using a MATLAB
% parallel pool. Each parfor worker takes one first-block allocation and
% recursively enumerates blocks 2 to 4.

% Main Script

% Constants
months = 24;
initial_customers = 1000;
organic_growth = 25;
baseline_churn = 0.10;
baseline_revenue_per_customer = 100;
team_size = 20;
new_customers_per_team_member = 5;
account_manager_capacity = 25;
max_time = 86400; % Maximum time in seconds (24hrs)

% Initialize strategy and best values
initial_strategy = zeros(4, 5); % Modified for 4 intervals (6-month strategies)

% Define the total number of strategies to explore in parallel
num_strategies = (team_size + 1) * (team_size + 1);

% Preallocate arrays to store the best results from each parallel worker
best_revenues = zeros(num_strategies, 1);
best_strategies = cell(num_strategies, 1);

% Terminate any existing parallel pool
if ~isempty(gcp('nocreate'))
    delete(gcp('nocreate'));
end

% Create a new parallel pool
parpool;

% Start the global timer
global_start_time = tic;

% Use parallel computing to explore strategies
parfor idx = 1:num_strategies
    % Check if global time limit has been reached
    if toc(global_start_time) > max_time
        % Terminate if time limit exceeded
        best_revenues(idx) = -Inf;
        best_strategies{idx} = [];
        continue;
    end

    [support_team_size, new_business_team_size] = ind2sub([team_size + 1, team_size + 1], idx);
    % Fix (Nov 2026): ind2sub returns 1-based subscripts, so subtract 1 to map idx onto
    % headcounts 0..20. The version run for the report omitted this line, which skipped
    % the 41 first-block allocations with zero Support or zero New Business staff; the
    % optimum is unchanged (see README, "Known issue and verification").
    support_team_size = support_team_size - 1;
    new_business_team_size = new_business_team_size - 1;

    if support_team_size + new_business_team_size <= team_size
        account_management_team_size = team_size - support_team_size - new_business_team_size;
        strategy = initial_strategy;
        strategy(1, :) = [support_team_size, new_business_team_size, account_management_team_size, 0, 0]; % Modified for 5 columns

        % Initialize the best revenue and strategy for this worker
        local_best_revenue = -Inf;
        local_best_strategy = strategy;

        % Start timing for this worker
        worker_tic = tic;

        % Explore remaining intervals sequentially for this starting strategy
        [local_best_revenue, local_best_strategy] = explore_strategies_parallel(2, strategy, local_best_revenue, ...
            local_best_strategy, 4, team_size, initial_customers, organic_growth, baseline_churn, ...
            baseline_revenue_per_customer, new_customers_per_team_member, account_manager_capacity, max_time, worker_tic);

        % Store the results
        best_revenues(idx) = local_best_revenue;
        best_strategies{idx} = local_best_strategy;
    end
end

% Gather the best overall strategy
[best_revenue, best_idx] = max(best_revenues);
best_strategy = best_strategies{best_idx};

% Initialize a table for the 6-month interval strategy
interval_strategy = zeros(4, 5); % Columns: SupportTeamSize, NewBusinessTeamSize, AccountManagementTeamSize, Cumulative Revenue, Cumulative Customer Base

% Calculate cumulative values every 6 months and output interval table
for interval = 1:4
    [total_revenue, final_customers, ~] = simulate_dynamic_strategy(best_strategy(1:interval, 1:3), interval * 6, ...
        initial_customers, organic_growth, baseline_churn, baseline_revenue_per_customer, ...
        new_customers_per_team_member, account_manager_capacity);

    % Fill in the strategy allocations
    interval_strategy(interval, 1:3) = best_strategy(interval, 1:3);
    interval_strategy(interval, 4) = total_revenue;   % Cumulative revenue
    interval_strategy(interval, 5) = final_customers; % Cumulative customer base
end

% Create the month-interval labels
interval_labels = strcat(num2str((1:6:19)'), '-', num2str((6:6:24)'));

% Create a table with the interval labels and strategy data
interval_table = table(interval_labels, ...
                       best_strategy(:, 1), ...
                       best_strategy(:, 2), ...
                       best_strategy(:, 3), ...
                       interval_strategy(:, 4), ...
                       interval_strategy(:, 5), ...
                       'VariableNames', {'MonthInterval', 'SupportTeamSize', 'NewBusinessTeamSize', ...
                       'AccountManagementTeamSize', 'CumulativeRevenue', 'CumulativeCustomerBase'});

% Output the interval results table
fprintf('Interval Cumulative Revenue and Customer Base:\n');
disp(interval_table);

% Save interval table as an Excel file
filename = 'Best_Strategy.xlsx';
writetable(interval_table, filename);

% Initialize a table to store monthly cumulative revenue and customer base
monthly_strategy = zeros(months, 6); % Columns: Month, SupportTeamSize, NewBusinessTeamSize, AccountManagementTeamSize, Cumulative Revenue, Cumulative Customer Base

% Calculate cumulative values every month and output monthly table
for month = 1:months
    interval = ceil(month / 6);
    [total_revenue, final_customers, ~] = simulate_dynamic_strategy(best_strategy(1:interval, 1:3), month, ...
        initial_customers, organic_growth, baseline_churn, baseline_revenue_per_customer, ...
        new_customers_per_team_member, account_manager_capacity);

    % Fill in the month and strategy allocations based on the current interval
    monthly_strategy(month, 1) = month;
    monthly_strategy(month, 2:4) = best_strategy(interval, 1:3);
    monthly_strategy(month, 5) = total_revenue;   % Cumulative revenue for the month
    monthly_strategy(month, 6) = final_customers; % Cumulative customer base for the month
end

% Output the monthly results table
monthly_table = array2table(monthly_strategy, 'VariableNames', {'Month', 'SupportTeamSize', 'NewBusinessTeamSize', ...
    'AccountManagementTeamSize', 'CumulativeRevenue', 'CumulativeCustomerBase'});
fprintf('Monthly Cumulative Revenue and Customer Base:\n');
disp(monthly_table);

% Save monthly table as an Excel file
monthly_filename = 'Monthly_Strategy.xlsx';
writetable(monthly_table, monthly_filename);

% Plot revenue growth over time (monthly)
figure;
plot(1:months, monthly_strategy(:, 5));
title('Revenue Growth Over Time (Monthly)');
xlabel('Month');
ylabel('Cumulative Revenue');
grid on;

% Plot customer base growth over time (monthly)
figure;
plot(1:months, monthly_strategy(:, 6));
title('Customer Base Growth Over Time (Monthly)');
xlabel('Month');
ylabel('Cumulative Customer Base');
grid on;

% Shut down parallel pool
delete(gcp);

% Function Definitions

% Function to calculate the total revenue, final customer base, and churn rate
function [total_revenue, final_customers, final_churn_rate] = simulate_dynamic_strategy(allocations, months, ...
        initial_customers, organic_growth, baseline_churn, baseline_revenue_per_customer, ...
        new_customers_per_team_member, account_manager_capacity)
    customer_base = initial_customers;
    total_revenue = 0;
    for month = 1:months
        support_team_size = allocations(ceil(month/6), 1);
        new_business_team_size = allocations(ceil(month/6), 2);
        account_management_team_size = allocations(ceil(month/6), 3);

        max_customers_under_management = account_management_team_size * account_manager_capacity;

        % Adjust churn rate based on CSAT improvement from the support team
        churn_rate = baseline_churn * (0.85 ^ support_team_size);
        churned_customers = floor(customer_base * churn_rate);
        new_customers = organic_growth + new_business_team_size * new_customers_per_team_member;

        % Update customer base
        customer_base = customer_base - churned_customers + new_customers;

        % Calculate revenue from managed and non-managed customers
        managed_customers = min(customer_base, max_customers_under_management);
        non_managed_customers = customer_base - managed_customers;
        revenue_from_managed = managed_customers * baseline_revenue_per_customer * (1 + 0.20)^min(month, 6);
        revenue_from_non_managed = non_managed_customers * baseline_revenue_per_customer;
        total_revenue = total_revenue + revenue_from_managed + revenue_from_non_managed;
    end
    final_customers = customer_base;
    final_churn_rate = churn_rate;
end

% Recursive function to explore all strategies (adjusted for parallel execution)
function [best_revenue, best_strategy] = explore_strategies_parallel(interval, strategy, best_revenue, best_strategy, ...
        total_intervals, team_size, initial_customers, organic_growth, baseline_churn, ...
        baseline_revenue_per_customer, new_customers_per_team_member, account_manager_capacity, max_time, worker_tic)
    % Check elapsed time
    if toc(worker_tic) > max_time
        return;
    end
    if interval > total_intervals
        % End of recursion, calculate the performance of the strategy
        [total_revenue, ~, ~] = simulate_dynamic_strategy(strategy, total_intervals * 6, initial_customers, ...
            organic_growth, baseline_churn, baseline_revenue_per_customer, new_customers_per_team_member, ...
            account_manager_capacity);
        if total_revenue > best_revenue
            best_revenue = total_revenue;
            best_strategy = strategy;
        end
    else
        % Loop through all possible team allocations for this interval
        for support_team_size = 0:team_size
            for new_business_team_size = 0:(team_size - support_team_size)
                account_management_team_size = team_size - support_team_size - new_business_team_size;
                strategy(interval, :) = [support_team_size, new_business_team_size, account_management_team_size, 0, 0]; % Modified for 5 columns
                % Recursively explore the next interval
                [best_revenue, best_strategy] = explore_strategies_parallel(interval + 1, strategy, best_revenue, ...
                    best_strategy, total_intervals, team_size, initial_customers, organic_growth, baseline_churn, ...
                    baseline_revenue_per_customer, new_customers_per_team_member, account_manager_capacity, max_time, worker_tic);
            end
        end
    end
end
