To build a docker project.

docker build -t frappe-bench .

To run

docker run --name frappe-bench-container -d -p 8000:8000 -p 9000:9000 -p 3306:3306 frappe-bench