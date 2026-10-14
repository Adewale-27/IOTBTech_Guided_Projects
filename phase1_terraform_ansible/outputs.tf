output "ctrl_instance_public_ip" {
  value = aws_instance.ctrl-linux.public_ip
}

output "project_instance_public_ip" {
  value = aws_instance.project-linux.public_ip
}

output "vpc_id" {
  value = aws_vpc.main.id
}

output "public_subnet_id" {
  value = aws_subnet.public.id
}

output "ssh_command" {
  value = "ssh -i <your-key>.pem ubuntu@${aws_instance.ctrl-linux.public_ip}"
}

output "ssh_command_project" {
  value = "ssh -i <your-key>.pem ubuntu@${aws_instance.project-linux.public_ip}"
}
