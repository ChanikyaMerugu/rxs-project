resource "aws_security_group" "traffic_sg" {
  name        = "traffic_sg"
  description = "Allow HTTP inbound connections"
  vpc_id = var.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
  }

  tags = {
    Name = "traffic_sg"
  }
}


### Creating Launch Configuration
resource "aws_launch_configuration" "frontend" {
  name_prefix = "frontend"

  image_id = var.ami
  instance_type = "t2.micro"
  key_name = "Chanu"

  security_groups = [ aws_security_group.traffic_sg.id ]
  associate_public_ip_address = true
  user_data = <<EOF
          #! /bin/bash
          yum update -y 
          yum install -y httpd.x86_64
          systemctl start httpd.service
          systemctl enable httpd.service
          echo "<h1>Hello World <span id = 'datetime'></span></h1><script>
          var dt = new Date();
          document.getElementById('datetime').innerHTML =dt.toLocaleString();</script>" > /var/www/html/index.html
EOF
}


## Creating  sg for loadbalancer
resource "aws_security_group" "security_elb" {
  name        = "security_elb"
  description = "Allow HTTP traffic "
  vpc_id = var.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
  }

}



## Creating  loadbalancer
resource "aws_elb" "elb" {
  name = "elb"
  security_groups = [
    aws_security_group.security_elb.id
  ]
  availability_zones = [var.azs[0], var.azs[1]]
  cross_zone_load_balancing   = true


  health_check {
    healthy_threshold = 2
    unhealthy_threshold = 2
    timeout = 3
    interval = 30
    target = "HTTP:80/"
  }

  listener {
    lb_port = 80
    lb_protocol = "http"
    instance_port = "80"
    instance_protocol = "http"
  }

}



## Creating  Autoscaling
resource "aws_autoscaling_group" "frontend_scaling" {
  name = "${aws_launch_configuration.frontend.name}-asg"

  min_size             = 1
  desired_capacity     = 3
  max_size             = 5
  
  health_check_type    = "ELB"
  load_balancers = [aws_elb.elb.id]
  launch_configuration = aws_launch_configuration.frontend.name
  enabled_metrics = [
    "GroupMinSize",
    "GroupMaxSize",
    "GroupDesiredCapacity",
    "GroupInServiceInstances",
    "GroupTotalInstances"
  ]
  metrics_granularity = "1Minute"
  availability_zones = [var.azs[0], var.azs[1]]
}


#creating a autoscaling policy and cloudwatch alarms

resource "aws_autoscaling_policy" "frontend_policy_up" {
  name = "frontend_policy_up"
  scaling_adjustment = 1
  adjustment_type = "ChangeInCapacity"
  cooldown = 300
  autoscaling_group_name = aws_autoscaling_group.frontend_scaling.name
}

resource "aws_cloudwatch_metric_alarm" "frontendAlarmHighCPU" {
  alarm_name = "frontendAlarmHighCPU"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods = "2"
  metric_name = "CPUUtilization"
  namespace = "AWS/EC2"
  period = "120"
  statistic = "Average"
  threshold = "80"

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.frontend_scaling.name
  }

  alarm_description = "This metric monitor EC2 instance CPU utilization"
  alarm_actions = [ aws_autoscaling_policy.frontend_policy_up.arn ]
}



resource "aws_autoscaling_policy" "frontend_policy_down" {
  name = "frontend_policy_down"
  scaling_adjustment = -1
  adjustment_type = "ChangeInCapacity"
  cooldown = 300
  autoscaling_group_name = aws_autoscaling_group.frontend_scaling.name
}

resource "aws_cloudwatch_metric_alarm" "frontendAlarmAdjustedCPU" {
  alarm_name = "frontendAlarmAdjustedCPU"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods = "2"
  metric_name = "CPUUtilization"
  namespace = "AWS/EC2"
  period = "120"
  statistic = "Average"
  threshold = "20"

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.frontend_scaling.name
  }

  alarm_description = "This metric monitor EC2 instance CPU utilization"
  alarm_actions = [ aws_autoscaling_policy.frontend_policy_down.arn ]
}