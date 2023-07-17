provider "aws"{
    region = "us-west-1"
}

#VPC Configuration
module "vpc"{
    source = "terraform-aws-modules/vpc/aws"
    cidr = "10.1.0.0/16"
    name = "App VPC"
    azs = ["us-west-1a", "us-west-1"]
    public_subnets = ["10.1.0.0/24", "10.1.1.0/24"]
    public_subnet_names = ["PublicSubnet1", "PublicSubnet2"]
    private_subnets= ["10.1.2.0/24", "10.1.3.0/24","10.1.4.0/24","10.1.5.0/24" ]
    private_subnet_names= ["WPSubnet1", "WPSubnet2", "DBSubet1", "DBSubet2"]
    tags = {
        Terraform = "true"
        Environment = "dev"
  }
}

# ALB Configuration
module "alb"{
  source  = "terraform-aws-modules/alb/aws"
  version = "~> 8.0"
  name = "Application Load Balancer"
  subnets =  [module.vpc.private_subnets[0], module.vpc.private_subnets[1] ]
  security_groups = [module.albsg.security_group_id]

  http_tcp_listeners = [
    {
      port               = 443
      protocol           = "HTTPS"
      target_group_index = 0
    }
  ]


}

#Autoscaling Group with min of 2 Linux CPUS
module "asg"{
  source  = "terraform-aws-modules/autoscaling/aws"
  version = "6.10.0" 
  name = "wpserver"
  min_size = 2
  max_size = 4
  desired_capacity = 2
  availability_zones = ["us-west-1a", "us-west-1b"]
  vpc_zone_identifier = [module.vpc.private_subnets[0],module.vpc.private_subnets[1] ]
  target_group_arns = [module.alb.target_group_arns[0]]
  health_check_type = "EC2"

  #Launch Template config
  launch_template_name        = "WebServer ASG"
  launch_template_description = "Launch Template for the web server autoscaling group"
  update_default_version      = true

  image_id          = "ami-0dc8c969d30e42996"
  instance_type     = "t3a.micro"
  ebs_optimized     = true
  enable_monitoring = true
  block_device_mappings = [
    {
      # Root volume
      device_name = "/dev/xvda"
      no_device   = 0
      ebs = {
        delete_on_termination = true
        encrypted             = true
        volume_size           = 20
        volume_type           = "gp2"
      }
      }
  ]
  network_interfaces = [
    {
      delete_on_termination = true
      description           = "eth0"
      device_index          = 0
      security_groups       = [module.asg_sg.security_group_id]
    },
  ]
  # config scaling policies
  scaling_policies = {
    avg-cpu-policy-greater-than-50 = {
      policy_type               = "TargetTrackingScaling"
      estimated_instance_warmup = 1200
      target_tracking_configuration = {
        predefined_metric_specification = {
          predefined_metric_type = "ASGAverageCPUUtilization"
        }
        target_value = 50.0
      }
    }
}
}


# configure the bastion 
module "bastion1"{
    source  = "terraform-aws-modules/ec2-instance/aws"
    ami    = "ami-0d2cf42446f3c926b"
    instance_type= "t3a.medium"
    key_name = "BastionKP"
    availability_zone = "us-west1a"
    subnet_id = module.vpc.public_subnets[0]
    vpc_security_group_ids = [module.bastionsg.security_group_id]
    root_block_device = [
        {
        encrypted   = true
        volume_type = "gp3"
        throughput  = 200
        volume_size = 50
        tags = {
            Name = "bastion2-root-block"
        }
        },
    ]

}

#Configure RDS
module "rds" {
  source = "terraform-aws-modules/rds/aws"
  identifier = "posgresql"
  engine = "postgres"
  instance_class = "db.t3.micro"
  db_name = "Infrastructure DB"
  vpc_security_group_ids = [module.dbsg.security_group_id]
  subnet_ids = [module.vpc.private_subnets[2], module.vpc.private_subnets[3]]
  backup_retention_period   =  0
  apply_immediately = true

}

#Configure security groups

# code to get ip code: https://stackoverflow.com/questions/46763287/i-want-to-identify-the-public-ip-of-the-terraform-execution-environment-and-add
data "http" "myip" {
  url = "http://ipv4.icanhazip.com"
}

#Bastion sg to accept traffic from just my ip for testing
module "bastionsg" {
    source = "terraform-aws-modules/security-group/aws"
    name = "Bastionsg"
    vpc_id = module.vpc.vpc_id
    ingress_with_cidr_blocks= [
        {
            description = "Allows RDP"
            to_port = 3389
            from_port = 3389
            protocol= "tcp"
            cidr_blocks = "${chomp(data.http.myip.body)}/32"
        },

    ]


}

# Only accept HTTPS traffic from internet
module "albsg"{
    source = "terraform-aws-modules/security-group/aws"
    name = "ALBsg"
    vpc_id = module.vpc.vpc_id
    ingress_with_cidr_blocks =  [
        {
        from_port   = 443
        to_port     = 443
        protocol    = "tcp"
        description = "HTTPS from Internet"
        cidr_blocks = "0.0.0.0/0"
        },
    ]
}

#only accept http traffic from ASG
module "webappsg" {
    source = "terraform-aws-modules/security-group/aws"
    vpc_id = module.vpc.vpc_id
    name = "WebAppSG"
    computed_ingress_with_source_security_group_id= [
        {
            description = "https traffic only from application load balancer"
            to_port = 443
            from_port = 443
            protocol= "tcp"
            source_security_group_id = module.albsg.security_group_id
        },
        {
            description= "accepts ssh from bastion host"
            to_port = 22
            from_port = 22
            protocol = "tcp"
            source_security_group_id =module.bastionsg.security_group_id
        },

    ]


}

# only accepts traffic from the webapp security group
module "dbsg"{
    source = "terraform-aws-modules/security-group/aws"
    vpc_id = module.vpc.vpc_id
    name ="RDSsg"
    computed_ingress_with_source_security_group_id= [
        {
            description = "https traffic only from web app security group"
            to_port = 5432
            from_port = 5432
            protocol= "tcp"
            source_security_group_id = module.webappsg.security_group_id
        },

    ]



}


#TODO
# finish autoscaling group and alb
# configure autoscaling group with application load balancer