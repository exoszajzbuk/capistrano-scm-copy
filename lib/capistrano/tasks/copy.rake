namespace :copy do
  archive_name = "archive.tar.gz"

  desc "Archive files to #{archive_name}"
  file archive_name => FileList['*'].exclude(archive_name) do |t|
    includes     = Array(fetch(:copy_include))
    excludes     = Dir.glob('*') - includes
    exclude_args = excludes.map { |item| "--exclude '#{item}'"}
    tar_verbose  = fetch(:tar_verbose, false) ? "v" : ""

    cmd = ["tar -c#{tar_verbose}zf #{t.name}", *exclude_args, *t.prerequisites]
    sh cmd.join(' ')
  end

  desc "Deploy #{archive_name} to release_path"
  task :deploy => archive_name do |t|
    tar_roles = fetch(:tar_roles, :all)
    tarball = t.prerequisites.first

    on roles(tar_roles) do
      # Make sure the release directory exists
      execute :mkdir, "-p", release_path

      # Create a temporary file on the server
      tmp_file = capture("mktemp")

      # Upload the archive, extract it and finally remove the tmp_file
      upload!(tarball, tmp_file)
      execute :tar, "-xzf", tmp_file, "-C", release_path
      execute :rm, tmp_file
    end
  end

  task :clean do |t|
    # Delete the local archive
    File.delete archive_name if File.exists? archive_name
  end

  after 'deploy:finished', 'copy:clean'

  task :create_release => :deploy
  task :check
  task :set_current_revision do |t|
    run_locally do
      revision = capture(:git, "rev-list --max-count=1 --abbrev-commit #{fetch(:branch)}").strip
      set :current_revision, revision
    end
  end
end
