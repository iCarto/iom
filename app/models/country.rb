# == Schema Information
#
# Table name: countries
#
#  id               :integer         not null, primary key
#  name             :string(255)
#  code             :string(255)
#  wiki_url         :string(255)
#  wiki_description :text
#  iso2_code        :string(255)
#  iso3_code        :string(255)
#  the_geom         :string
#

class Country < ActiveRecord::Base

  has_many :regions
  has_and_belongs_to_many :projects do
    def site(site)
      self.where("projects.id IN (#{site.projects_ids.join(',')})")
    end
  end

  before_save :update_wikipedia_description

  def self.custom_fields
    (columns.map{ |c| c.name } - ['the_geom']).map{ |c| "#{self.table_name}.#{c}" }
  end

  # Array of arrays
  # [[cluster, count], [cluster, count]]
  def projects_clusters(site)
    sql="select c.id,c.name,count(ps.*) as count from clusters as c
    inner join clusters_projects as cp on c.id=cp.cluster_id
    inner join countries_projects as cop on cp.project_id=cop.project_id
    inner join projects_sites as ps on cop.project_id=ps.project_id and ps.site_id=#{site.id}
    group by c.id,c.name"
    Cluster.find_by_sql(sql).map do |c|
      [c,c.count.to_i]
    end
  end

  # Array of arrays
  # [[region, count], [region, count]]
  def regions_projects(site)
    sql="select c.id,c.name,count(ps.*) as count from clusters as c
    inner join clusters_projects as cp on c.id=cp.cluster_id
    inner join projects_regions as pr on cp.project_id=pr.project_id
    inner join projects_sites as ps on pr.project_id=ps.project_id and ps.site_id=#{site.id}
    group by c.id,c.name"
    Cluster.find_by_sql(sql).map do |c|
      [c,c.count.to_i]
    end
  end

  def donors_count(site)
    ActiveRecord::Base.connection.execute(<<-SQL
      select count(distinct(donor_id)) as count from donations as d
      inner join projects_sites as ps on d.project_id=ps.project_id and ps.site_id=#{site.id}
      inner join countries_projects as cp on ps.project_id=cp.project_id and cp.country_id=#{self.id}
    SQL
    ).first['count'].to_i
  end

  def donors(site, limit = 10)
    sql="select donors.* from donors
    inner join donations as d on donors.id=d.donor_id
    inner join projects_sites as ps on d.project_id=ps.project_id and ps.site_id=#{site.id}
    inner join countries_projects as cp on ps.project_id=cp.project_id and cp.country_id=#{self.id}
    LIMIT #{limit}"
    Donor.find_by_sql(sql)
  end

  # to get only id and name
  def self.get_select_values
    scoped.select(:id,:name).order("name ASC")
  end

  def update_wikipedia_description
    if wiki_url.present?
      require 'open-uri'
      doc = Nokogiri::HTML(open(URI.encode(wiki_url), 'User-Agent' => 'NgoAidMap.net'))

      #SUCK OUT ALL THE PARAGRAPHS INTO AN ARRAY
      #CLEANING UP TEXT REMOVING THE '[\d+]'s
      paragraphs = doc.css('#bodyContent p').inject([]) {|a,p|
        a << p.content.gsub(/\[\d+\]/,"")
        a
      }

      self.wiki_description = paragraphs.first if paragraphs.present?
    end
  end
  private :update_wikipedia_description

  def near(site, limit = 5)
    Country.find_by_sql(<<-SQL
      select * from
      (select co.id, co.name,
           ST_Distance((select ST_Centroid(the_geom) from countries where id=#{self.id}), ST_Centroid(the_geom)) as dist,
           (select count(*) from countries_projects as cp where country_id=co.id) as count
           from countries as co
           where id!=#{self.id}
           order by dist
      ) as subq
      where count>0
      limit  #{limit}
SQL
    )
  end

end
