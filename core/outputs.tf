output "eks_output" {
  value = aws_eks_cluster.nmckinley["prod"].id
}
