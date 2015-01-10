#
# Cookbook Name:: scala-jenkins-infra
# Recipe:: _master-config-jobs
#
# Copyright 2014, Typesafe, Inc.
#
# All rights reserved - Do Not Redistribute
#

require "chef-vault"

ruby_block 'set private key' do
  block do
    node.run_state[:jenkins_private_key] = ChefVault::Item.load("master", "scala-jenkins-keypair")['private_key']
  end
end


# TODO: is there no shorter way??
class Blurbs
  include ScalaJenkinsInfra::JobBlurbs
end

# turn template path into jenkins job name
def templDesc(version, path)
  blurbs = Blurbs.new

  m = path.match(/templates\/default\/jobs\/(.*)\.xml\.erb$/)
  if m == nil
    []
  else
    relativePath = m.captures.first

    [ { :templatePath => "jobs/#{relativePath}.xml.erb",
        :scriptName   => "jobs/#{relativePath}",
        :jobName      => blurbs.versionedJob(version, relativePath),
        :version      => version
      }
    ]
  end
end

# create scala-$version-$jobName for every template under jobs/
%w{ 2.11.x }.each do | version |
  node.run_context.cookbook_collection["scala-jenkins-infra"].manifest[:templates]
    .flat_map { |mani| templDesc(version, mani['path']) }
    .each do | desc |

    xml = File.join(Chef::Config[:file_cache_path], "#{desc[:jobName]}.xml")

    template xml do
      variables(desc)

      source desc[:templatePath]
      helpers(ScalaJenkinsInfra::JobBlurbs)
    end

    jenkins_job desc[:jobName] do
      config xml
    end
  end
end

# TODO: make a view for each top-level directory under jobs/ that lists all jobs under it (scala-2.11.x-integrate, scala-2.11.x-release, scala-2.11.x-validate)
# https://issues.jenkins-ci.org/browse/JENKINS-8927
def viewXML(viewPrefix)
  <<-EOH.gsub(/^    /, '')
    <listView>
      <owner class="hudson" reference="../../.."/>
      <name>#{viewPrefix}</name>
      <filterExecutors>false</filterExecutors>
      <filterQueue>false</filterQueue>
      <properties class="hudson.model.View$PropertyList"/>
      <jobNames>
        <comparator class="hudson.util.CaseInsensitiveComparator"/>
      </jobNames>
      <jobFilters/>
      <columns>
        <hudson.views.StatusColumn/>
        <hudson.views.WeatherColumn/>
        <hudson.views.JobColumn/>
        <hudson.views.LastSuccessColumn/>
        <hudson.views.LastFailureColumn/>
        <hudson.views.LastDurationColumn/>
        <hudson.views.BuildButtonColumn/>
      </columns>
      <includeRegex>#{viewPrefix}-.*</includeRegex>
      <recurse>false</recurse>
      <statusFilter>true</statusFilter>
    </listView>
  EOH
end