% SaaS_Model_False.m
% Baseline: a hand-picked allocation of a 20-person team across Support,
% New Business and Account Management, evaluated over 24 months.
% Columns: SupportTeamSize, NewBusinessTeamSize, AccountManagementTeamSize

% Strategy based on user input
strategy = [
    5, 10, 5;    % Months 1-6:   Support = 5,  New Business = 10, Account Management = 5
    5, 5, 10;    % Months 7-12:  Support = 5,  New Business = 5,  Account Management = 10
    10, 5, 5;    % Months 13-18: Support = 10, New Business = 5,  Account Management = 5
    10, 5, 5;    % Months 19-24: Support = 10, New Business = 5,  Account Management = 5
];

% Constants
months = 24;
initial_customers = 1000;
organic_growth = 25;
baseline_churn = 0.1;
baseline_revenue_per_customer = 100;
new_customers_per_team_member = 5;
account_manager_capacity = 25;

% Initialize the customer base and total revenue
customer_base = initial_customers;
total_revenue = 0;

% Iterate through the 24 months, applying the strategy
for month = 1:months
    % Determine the strategy interval (1-6, 7-12, 13-18, 19-24)
    interval = ceil(month / 6);

    % Extract the current interval strategy
    support_team_size = strategy(interval, 1);
    new_business_team_size = strategy(interval, 2);
    account_management_team_size = strategy(interval, 3);

    % Calculate the max customers under management
    max_customers_under_management = account_management_team_size * account_manager_capacity;

    % Adjust churn rate based on CSAT improvement from the support team
    churn_rate = baseline_churn * (0.85 ^ support_team_size);
    churned_customers = floor(customer_base * churn_rate);

    % Calculate new customers acquired
    new_customers = organic_growth + new_business_team_size * new_customers_per_team_member;

    % Update the customer base
    customer_base = customer_base - churned_customers + new_customers;

    % Calculate revenue from managed and non-managed customers
    managed_customers = min(customer_base, max_customers_under_management);
    non_managed_customers = customer_base - managed_customers;
    revenue_from_managed = managed_customers * baseline_revenue_per_customer * (1 + 0.20)^min(month, 6);
    revenue_from_non_managed = non_managed_customers * baseline_revenue_per_customer;
    total_revenue = total_revenue + revenue_from_managed + revenue_from_non_managed;
end

% Display the total revenue and final customer base
fprintf('Total Revenue after 24 months: $%.2f\n', total_revenue);
fprintf('Final Customer Base after 24 months: %d customers\n', customer_base);
