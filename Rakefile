task :default => ['build']

desc 'Build the task image'
task :build, [:image, :tag, :auto_latest] do |task, args|
  args.with_defaults(image: 'cid01554/jid01495/ifg_claim_mgmt_sync', tag: 'latest', auto_latest: true)
  tags = ["#{args.image}:#{args.tag}"]
  if args.tag != 'latest' && args.auto_latest
    tags << "#{args.image}:latest"
  end
  tag_args = tags.map { |t| "-t #{t}" }.join(' ')
  sh("docker build . #{tag_args}")
end

desc 'Login to AWS ECR'
task :login, [:repository_url, :profile, :region] do |task, args|
  args.with_defaults(
    repository_url: '681585688392.dkr.ecr.us-east-1.amazonaws.com',
    profile: 'ifg_claim_mgmt_sync_user',
    region: 'us-east-1'
  )
  sh("aws ecr --profile #{args.profile} get-login-password --region #{args.region} | docker login --username AWS --password-stdin #{args.repository_url}")
end

desc 'Push image to AWS ECR repository'
task :push, [:repository_url, :image, :tag] do |task, args|
  args.with_defaults(
    repository_url: '681585688392.dkr.ecr.us-east-1.amazonaws.com',
    image: 'cid01554/jid01495/ifg_claim_mgmt_sync',
    tag: 'latest'
  )
  image_src = "#{args.image}:#{args.tag}"
  repository_image_src = "#{args.repository_url}/#{image_src}"
  sh("docker tag #{image_src} #{repository_image_src}")
  sh("docker push #{repository_image_src}")
end
