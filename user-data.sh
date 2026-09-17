#!/bin/bash

dnf update -y
dnf install -y nginx git
systemctl enable nginx
systemctl start nginx
mkdir -p /var/www/student-site
chown -R nginx:nginx /var/www/student-site
chmod -R 755 /var/www/student-site

cat > /var/www/student-site/index.html <<'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>AWS Nginx Lab</title>
</head>
<body>
    <h1>AWS Nginx Web Server</h1>
    <p>Website deployed successfully.</p>
</body>
</html>
EOF

cat > /etc/nginx/conf.d/student-site.conf <<'EOF'
server {
    listen 80;
    server_name _;

    root /var/www/student-site;
    index index.html;

    location / {
        try_files $uri $uri/ =404;
    }
}
EOF

nginx -t
systemctl restart nginx
