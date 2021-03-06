class Monologue::Post
  include Mongoid::Document
  include Mongoid::Timestamps

  has_many :taggings, class_name: "Monologue::Tagging"
  has_and_belongs_to_many :tags, dependent: :destroy, class_name: "Monologue::Tag", order: [:created_at, :asc]
  before_validation :generate_url
  belongs_to :user, class_name: "Monologue::User"

  field :title, type: String
  field :content, type: String
  field :url, type: String
  
  field :published_at, type: Time
  field :published, type: Boolean

  scope :default,  -> {order([[:published_at, :desc], [:created_at, :desc], [:updated_at, :desc]]) }
  scope :published, -> { default.where(:published_at.lte => DateTime.now, published: true).order([[:published_at, :desc]]) }

  default_scope -> {includes(:tags)}

  validates :user_id, presence: true
  validates :title, :content, :url, :published_at, presence: true
  validates :url, uniqueness: true
  validate :url_do_not_start_with_slash

  index({published_at: 1, published: 1})
  index({published_at: 1, published: 1, url: 1})

  def tag_list= tags_attr
    self.tag!(tags_attr.split(","))
  end

  def tag_list
    self.tags.pluck(:name).join(", ") if self.tags
  end

  def tag!(tags_attr)
    self.tags = tags_attr.map(&:strip).reject(&:blank?).map do |tag|
      Monologue::Tag.where(name: tag).first_or_create
    end
  end

  def full_url
    "#{Monologue::Engine.routes.url_helpers.root_path}#{self.url}"
  end

  def published_in_future?
    self.published && self.published_at > DateTime.now
  end

  def self.page p
    paged_results(p, Monologue::Config.posts_per_page || 10, false)
  end

  def self.listing_page(p)
    paged_results(p, Monologue::Config.admin_posts_per_page || 50, true)
  end

  def self.total_pages
    @number_of_pages
  end

  def self.set_total_pages per_page
    @number_of_pages = self.count / per_page + (self.count % per_page == 0 ? 0 : 1)
  end

  private

  def self.paged_results(p, per_page, admin)
    set_total_pages(per_page)
    p = (p.nil? ? 0 : p.to_i - 1)
    offset =  p * per_page
    if admin
      default.limit(per_page).offset(offset)
    else
      limit(per_page).offset(offset)
    end
  end

  def generate_url
    return unless self.url.blank?
    year = self.published_at.class == ActiveSupport::TimeWithZone ? self.published_at.year : DateTime.now.year
    self.url = "#{year}/#{self.title.parameterize}"
  end

  def url_do_not_start_with_slash
    errors.add(:url, I18n.t("mongoid.errors.models.monologue/post.attributes.url.start_with_slash")) if self.url.start_with?("/")
  end
end
