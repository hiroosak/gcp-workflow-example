select
  count(customer_id) as num_customers
from {{ ref('customers') }}
having
 num_customers < 0
