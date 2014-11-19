guard :rspec, cmd: 'bundle exec rspec' do
  watch(%r{^spec/.+_spec\.rb$})
  watch(%r{^spec/[^/]+\.rb$}) { "spec" }
  watch(%r{^lib/.+rb$}) { "spec" }
end



