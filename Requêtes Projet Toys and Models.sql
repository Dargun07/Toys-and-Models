#Le nombre de produits vendus par catégorie et par mois, avec comparaison et taux de variation par rapport au même mois de l’année précédente.

SELECT products.productLine, 
YEAR(orders.orderDate) AS Année, 
MONTH(orders.orderDate) AS Mois,
SUM(orderdetails.quantityOrdered) AS Quantité_total,
LAG(SUM(orderdetails.quantityOrdered)) OVER (PARTITION BY products.productLine, MONTH(orders.orderDate) ORDER BY YEAR(orders.orderDate)) AS Quantité_précédente_mois_année,
(SUM(orderdetails.quantityOrdered)) - LAG(SUM(orderdetails.quantityOrdered)) OVER (PARTITION BY products.productLine, MONTH(orders.orderDate) 
    ORDER BY YEAR(orders.orderDate)) as comparaison_année_précédente,
	((SUM(orderdetails.quantityOrdered)) - LAG(SUM(orderdetails.quantityOrdered)) OVER (PARTITION BY products.productLine, MONTH(orders.orderDate) 
    ORDER BY YEAR(orders.orderDate)))
	/(LAG(SUM(orderdetails.quantityOrdered)) OVER (PARTITION BY products.productLine, MONTH(orders.orderDate) ORDER BY YEAR(orders.orderDate))) as tx_variation
FROM orderdetails
INNER JOIN products ON products.productCode = orderdetails.productCode
INNER JOIN orders ON orderdetails.orderNumber = orders.orderNumber
GROUP BY products.productLine, YEAR(orders.orderDate), MONTH(orders.orderDate);


# Requête finance 
# Le chiffre d’affaires des commandes des deux derniers mois par pays.

SELECT customers.country, SUM(quantityOrdered*priceEach) AS CA
FROM orderdetails
JOIN orders ON orders.orderNumber = orderdetails.orderNumber 
JOIN customers ON customers.customerNumber = orders.customerNumber
WHERE YEAR(orderDate) = YEAR(NOW()) AND MONTH(orderDate) = MONTH(NOW())-9
GROUP BY customers.country
ORDER BY CA;

# Le chiffre d’affaires des commandes des deux derniers mois par pays.

SELECT customers.country, SUM(quantityOrdered*priceEach) AS CA
FROM orderdetails
JOIN orders ON orders.orderNumber = orderdetails.orderNumber 
JOIN customers ON customers.customerNumber = orders.customerNumber
WHERE YEAR(orderDate) = YEAR(NOW()) AND MONTH(orderDate) = MONTH(NOW())-8
GROUP BY customers.country
ORDER BY CA;

SELECT customers.country, 
SUM(quantityOrdered*priceEach) AS CA,
orders.orderDate,
MONTH(orders.orderDate),
MONTHNAME(orders.orderDate),
YEAR(orders.orderDate)
FROM orderdetails
JOIN orders ON orders.orderNumber = orderdetails.orderNumber 
JOIN customers ON customers.customerNumber = orders.customerNumber
WHERE orderDate BETWEEN '2024-01-01' AND '2024-02-29'
GROUP BY customers.country,orders.orderDate
ORDER BY CA;

SELECT customers.country, SUM(quantityOrdered*priceEach) AS CA
FROM orderdetails
JOIN orders ON orders.orderNumber = orderdetails.orderNumber 
JOIN customers ON customers.customerNumber = orders.customerNumber
WHERE orderDate BETWEEN '2024-01-01' AND '2024-01-31'
GROUP BY customers.country
ORDER BY CA;

SELECT customers.country, SUM(quantityOrdered*priceEach) AS CA
FROM orderdetails
JOIN orders ON orders.orderNumber = orderdetails.orderNumber 
JOIN customers ON customers.customerNumber = orders.customerNumber
WHERE orderDate BETWEEN '2024-02-01' AND '2024-02-29'
GROUP BY customers.country
ORDER BY CA;

# Les commandes qui n’ont pas encore été payées.

SELECT orderNumber, orderDate, amount, orders.status, shippedDate
FROM orders
JOIN customers ON customers.customerNumber = orders.customerNumber
JOIN payments ON payments.customerNumber = customers.customerNumber
WHERE status = "on hold";

WITH Total_Commandes AS (
	SELECT c.customerNumber, c.customerName, Sum(quantityOrdered * priceEach) as total_commandes
	FROM customers AS c
	INNER JOIN orders AS ord ON c.customerNumber = ord.customerNumber
	INNER JOIN orderdetails AS ordD ON ord.orderNumber = ordD.orderNumber
	group by c.customerNumber
),
Total_Paiements AS (
	SELECT p.customerNumber, sum(p.amount) AS total_paiements
	FROM payments AS p
    group by p.customerNumber
)
SELECT c.customerNumber, c.customerName, tc.total_commandes, tp.total_paiements, (tc.total_commandes - tp.total_paiements) AS diff
FROM customers AS c
INNER JOIN Total_Commandes AS tc ON c.customerNumber = tc.customerNumber
LEFT JOIN Total_Paiements AS tp ON c.customerNumber = tp.customerNumber
WHERE (tc.total_commandes - tp.total_paiements) > 0;



SELECT 
    customernumber,
    customername,
    country,
    creditlimit,
    debt 
FROM 
    (
        SELECT 
            subquery.customernumber,
            subquery.customername,
            subquery.country,
            creditlimit,
            ABS((real_payment - required_payment)) AS debt
        FROM
            (
                SELECT 
                    c.customerNumber,
                    c.customername,
                    c.country,
                    c.creditlimit,
                    SUM(quantityOrdered * priceEach) AS required_payment 
                FROM 
                    orderdetails AS od
                INNER JOIN 
                    orders AS o ON od.orderNumber = o.orderNumber
                INNER JOIN 
                    customers AS c ON c.customerNumber = o.customerNumber
                GROUP BY 
                    customerNumber
            ) AS subquery
        INNER JOIN 
            (
                SELECT 
                    SUM(amount) AS real_payment, 
                    customernumber 
                FROM 
                    payments 
                GROUP BY 
                    customernumber
            ) AS subquery_2 
        ON 
            subquery.customernumber = subquery_2.customernumber
    ) AS subquery_3
WHERE 
    debt > 0;

##Requêtes Logistique
#Logistique : Le stock des 5 produits les plus commandés.
use toys_and_models;

SELECT p.productcode, p.productname,p.quantityinstock, SUM(od.quantityOrdered) as somme
FROM products as p
JOIN orderdetails as od
ON od.productcode=p.productcode
JOIN orders as o
ON od.ordernumber=o.ordernumber
GROUP BY p.productcode
ORDER BY somme DESC;

#taux de service client
SELECT count(orderNumber)
FROM orders
WHERE status like 'shipped' and shippedDate <
 requiredDate;

#Cout des stocks
SELECT p.productCode, p.productline, p.productname, p.quantityinstock, p.buyprice, (p.quantityInStock*p.buyprice) as cout_stock
FROM products as p
ORDER BY cout_stock DESC;

##Requête RH
# Chaque mois les 2 vendeurs ayant réalisés le plus de CA
SELECT*
FROM
(
SELECT year(orderDate) AS annee, month(orderDate) AS mois, employeeNumber,lastName,firstName, CONCAT(lastName," ",firstname) AS name, SUM(quantityOrdered*priceEach) AS chiffre_affaire,
RANK()OVER(PARTITION BY year(orderDate),month(orderDate) ORDER BY SUM(quantityOrdered*priceEach) DESC) AS ranking
FROM orderdetails
JOIN orders
ON orders.orderNumber = orderdetails.orderNumber
JOIN customers
ON orders.customerNumber = customers.customerNumber
JOIN employees
ON employees.employeeNumber=customers.salesRepEmployeeNumber
GROUP BY annee, mois, employeeNumber
) AS new_table
HAVING ranking <3;


# Chiffre d'affaire et nombre de ventes des vendeurs chaque mois
SELECT employeeNumber,YEAR(orderDate) as annee, MONTH(OrderDate) as mois, lastName,firstName, offices.city, SUM(quantityOrdered*priceEach) AS chiffre_affaire, COUNT(orders.orderNumber) AS number_sales
FROM orderdetails
JOIN orders
ON orders.orderNumber = orderdetails.orderNumber
JOIN customers
ON orders.customerNumber = customers.customerNumber
JOIN employees
ON employees.employeeNumber=customers.salesRepEmployeeNumber
JOIN offices
ON offices.officeCode=employees.officeCode
GROUP BY annee, mois, employeeNumber
ORDER BY annee DESC, mois, chiffre_affaire DESC ;


# Chiffre d'affaire par office
SELECT YEAR(orderDate) AS annee, MONTH(orderDate) AS mois, SUM(quantityOrdered*priceEach) AS chiffre_affaire,offices.officeCode, offices.city
FROM products
JOIN orderdetails
ON products.productCode = orderdetails.productCode
JOIN orders
ON orders.orderNumber = orderdetails.orderNumber
JOIN customers
ON orders.customerNumber = customers.customerNumber
JOIN employees
ON employees.employeeNumber=customers.salesRepEmployeeNumber
JOIN offices
ON offices.officeCode = employees.officeCode
GROUP BY annee, mois, offices.officeCode ;