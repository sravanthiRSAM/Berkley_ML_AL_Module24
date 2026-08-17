select *
from [RevenueOperations].cpt.Active_Tickets
where ticket_id = '202434'

select *
from [RevenueOperations].cpt.Active_Tickets
where ticket_id = '202946'



SELECT ticket_id, Offer_ID, order_line_item , COUNT(*) AS cnt
FROM cpt.active_tickets
GROUP BY ticket_id, Offer_ID, order_line_item
HAVING COUNT(*) > 1

with cte As (
Select *,  COALESCE(order_line_item, 'NULL_PLACEHOLDER') As order_line_item_Null
from cpt.active_tickets
)
SELECT ticket_id, Offer_ID,  order_line_item_Null, COUNT(*) AS cnt
FROM cte
GROUP BY ticket_id, Offer_ID,order_line_item_Null
HAVING COUNT(*) > 1

SELECT ticket_id, order_line_item, COUNT(*) AS cnt
FROM cpt.active_tickets
WHERE order_line_item IS NULL
GROUP BY ticket_id, order_line_item
HAVING COUNT(*) > 1

UNION ALL

SELECT ticket_id, order_line_item, COUNT(*) AS cnt
FROM cpt.active_tickets
WHERE order_line_item IS NOT NULL
GROUP BY ticket_id, order_line_item
HAVING COUNT(*) > 1



Select *
from  cpt.active_tickets
WHERE order_line_item IS NULL
order by Create_date desc 

Select *
from  cpt.active_tickets
WHERE ticket_id = '202434'--'203479' (linteitem for addon's can be null)--'203737'(PH not getting lineitem)--'203925'--'204024'
order by Create_date desc 

Select *
from  cpt.active_tickets
WHERE ticket_id = '203479'--'203479' (linteitem for addon's can be null)--'203737'(PH not getting lineitem)--'203925'--'204024'
order by Create_date desc 



Select distinct ticket_id
from  cpt.active_tickets

-- Tickets with multiple status. This should not be the case. There is some issue in the pipeline
WITH multi_status_tickets AS (
    SELECT ticket_id
    FROM cpt.active_tickets
    GROUP BY ticket_id
    HAVING COUNT(DISTINCT status) > 1
)
/*
SELECT distinct
    t.ticket_id,
    t.status,
    t.Create_date
FROM cpt.active_tickets t
INNER JOIN multi_status_tickets m ON t.ticket_id = m.ticket_id
ORDER BY  t.Create_date;*/

/*
delete from cpt.active_tickets
where ticket_id in (select ticket_id from multi_status_tickets) 
and order_line_item is null*/


select ticket_id , status , Offer_ID , order_line_item , *
from  cpt.active_tickets
where ticket_id in (select ticket_id from multi_status_tickets) 
and order_line_item is null
ORDER BY  1 ,2


WITH TIX_NULL AS ( 
  SELECT DISTINCT 
  TICKET_ID
  , ORDER_LINE_ITEM
  FROM CPT.Active_Tickets
  WHERE ORDER_LINE_ITEM IS NULL)

, TIX AS (
  SELECT DISTINCT
  TICKET_ID
  , ORDER_LINE_ITEM
  , external_ticket_id
  FROM CPT.Active_Tickets
  WHERE ORDER_LINE_ITEM IS NOT NULL)


SELECT TIX.*, TN.order_line_item FROM TIX 
LEFT JOIN TIX_NULL TN ON TN.TICKET_ID = TIX.ticket_id
WHERE TN.ticket_id IS NOT NULL
and TIX_NUll 
ORDER BY TIX.TICKET_ID

select *
from CPT.Active_Tickets