# == Schema Information
#
# Table name: sites
#
#  id                              :integer         not null, primary key
#  name                            :string(255)
#  short_description               :text
#  long_description                :text
#  contact_email                   :string(255)
#  contact_person                  :string(255)
#  url                             :string(255)
#  permalink                       :string(255)
#  google_analytics_id             :string(255)
#  logo_file_name                  :string(255)
#  logo_content_type               :string(255)
#  logo_file_size                  :integer
#  logo_updated_at                 :datetime
#  theme_id                        :integer
#  blog_url                        :string(255)
#  word_for_clusters               :string(255)
#  word_for_regions                :string(255)
#  show_global_donations_raises    :boolean
#  project_classification          :integer         default(0)
#  geographic_context_country_id   :integer
#  geographic_context_region_id    :integer
#  project_context_cluster_id      :integer
#  project_context_sector_id       :integer
#  project_context_organization_id :integer
#  project_context_tags            :string(255)
#  created_at                      :datetime
#  updated_at                      :datetime
#  geographic_context_geometry     :geometry
#  project_context_tags_ids        :string(255)
#

class Site < ActiveRecord::Base

  acts_as_geom :the_geom => :polygon

  has_many :resources, :conditions => 'resources.element_type = #{Iom::ActsAsResource::SITE_TYPE}', :foreign_key => :element_id, :dependent => :destroy
  has_many :media_resources, :conditions => 'media_resources.element_type = #{Iom::ActsAsResource::SITE_TYPE}', :foreign_key => :element_id, :dependent => :destroy, :order => 'position ASC'
  has_one :theme
  has_many :partners, :dependent => :destroy
  has_many :pages, :dependent => :destroy

  has_attached_file :logo, :styles => { :small => "60x60#" }

  validates_presence_of :name, :url
  validates_uniqueness_of :url

  before_validation :clean_html

  attr_accessor :geographic_context, :project_context, :show_blog

  before_save :set_geographic_context, :set_project_context, :set_project_context_tags_ids

  def show_blog
    !blog_url.blank?
  end
  alias :show_blog? :show_blog


  # Filter projects from site configuration
  #
  # Use cases:
  #
  #  - cluster filtering (1)
  #    query: select projects.* from projects, clusters_projects where clusters_projects.project_id = projects.id and clusters_projects.cluster_id = #{cluster_id}
  #
  #  - sector filtering (2)
  #    query: select projects.* from projects, projects_sectors where projects_sectors.project_id = projects.id and projects_sectors.sector_id = #{sector_id}
  #
  #  - organizacion filtering (3)
  #    query: select projects.* from projects where projects.primary_organization_id = #{organization_id}
  #
  #  - tags filtering (4)
  #    query: select projects.* from projects, projects_tags where projects_tags.project_id = projects.id and projects_tags.id IN (#{tags_ids})
  #
  #  - country filtering (5)
  #    query: select projects.* from projects, countries_projects where countries_projects.project_id = projects.id and countries_projects.country_id = #{country_id}
  #
  #  - region filtering (6)
  #    query: select projects.* from projects, projects_regions where projects_regions.project_id = projects.id and projects_regions.region_id = #{region_id}
  #
  #  - bbox filtering (7)
  #    query : select projects.* from projects where ST_Contains(projects.the_geom, #{geographic_context_geometry})
  #
  def projects(options = {})
    default_options = { :limit => 10, :offset => 0 }
    options = default_options.merge(options)

    select = "distinct(projects.*)"
    from = ["projects"]
    where = []

    # (1)
    if project_context_cluster_id?
      from << "clusters_projects"
      where << "(clusters_projects.project_id = projects.id AND clusters_projects.cluster_id = #{project_context_cluster_id})"
    end

    # (2)
    if project_context_sector_id?
      from << "projects_sectors"
      where << "(projects_sectors.project_id = projects.id AND projects_sectors.sector_id = #{project_context_sector_id})"
    end

    # (3)
    if project_context_organization_id?
      where << "projects.primary_organization_id = #{project_context_organization_id}"
    end

    # (4)
    if project_context_tags_ids?
      from << "projects_tags"
      where << "(projects_tags.project_id = projects.id AND projects_tags.tag_id IN (#{project_context_tags_ids}))"
    end

    # (5)
    if geographic_context_country_id?
      from << "countries_projects"
      where << "(countries_projects.project_id = projects.id AND countries_projects.country_id = #{geographic_context_country_id})"
    end

    # (6)
    if geographic_context_region_id?
      from << "projects_regions"
      where << "(projects_regions.project_id = projects.id AND projects_regions.region_id = #{geographic_context_region_id})"
    end

    # (7)
    if geographic_context_geometry?
      where << "ST_Contains(projects.the_geom, #{geographic_context_geometry})"
    end

    result = Project.select(select).from(from.join(',')).where(where.join(' OR '))
    if options[:limit]
      result = result.limit(options[:limit])
      if options[:offset]
        result = result.offset(options[:offset])
      end
    end
    result.all
  end

  # TODO: with a count()
  def total_projects(options = {})
    projects(options).size
  end

  private

    def clean_html
      %W{ name short_description long_description contact_person contact_email url permalink }.each do |att|
        eval("self.#{att} = Sanitize.clean(self.#{att}.gsub(/\r/,'')) unless self.#{att}.blank?")
      end
    end

    def set_geographic_context
      unless geographic_context.blank?
        case geographic_context
        when 'worlwide'
          self.geographic_context_country_id = nil
          self.geographic_context_region_id  = nil
          self.geographic_context_geometry   = nil
        when 'country'
          self.geographic_context_region_id  = nil
          self.geographic_context_geometry   = nil
        when 'region'
          self.geographic_context_country_id = nil
          self.geographic_context_geometry   = nil
        when 'bbox'
          self.geographic_context_geometry   = nil
        end
      end
    end

    def set_project_context
      return if project_context.blank?
      unless project_context.include?('tags')
        self.project_context_tags = nil
      end
      unless project_context.include?('cluster')
        self.project_context_cluster_id = nil
      end
      unless project_context.include?('organization')
        self.project_context_organization_id = nil
      end
    end

    def set_project_context_tags_ids
      return if project_context_tags.blank?
      tag_names = project_context_tags.split(',').map{ |t| t.strip }.compact.delete_if{ |t| t.blank? }
      self.project_context_tags_ids = tag_names.map{ |tag_name| Tag.find_by_name(tag_name).try(:id) }.compact.join(',')
    end

end