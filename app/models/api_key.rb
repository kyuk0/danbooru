class ApiKey < ApplicationRecord
  array_attribute :permissions
  array_attribute :permitted_ip_addresses

  normalize :permissions, :normalize_permissions
  normalize :name, :normalize_text

  belongs_to :user
  validate :validate_permissions, if: :permissions_changed?
  validates :key, uniqueness: true, if: :key_changed?
  has_secure_token :key

  def self.visible(user)
    if user.is_owner?
      all
    else
      where(user: user)
    end
  end

  def self.search(params)
    q = search_attributes(params, :id, :created_at, :updated_at, :key, :user)
    q = q.apply_default_order(params)
    q
  end

  concerning :PermissionMethods do
    def has_permission?(ip, controller, action)
      ip_permitted?(ip) && action_permitted?(controller, action)
    end

    def ip_permitted?(ip)
      return true if permitted_ip_addresses.empty?
      permitted_ip_addresses.any? { |permitted_ip| ip.in?(permitted_ip) }
    end

    def action_permitted?(controller, action)
      return true if permissions.empty?

      permissions.any? do |permission|
        permission == "#{controller}:#{action}"
      end
    end

    def validate_permissions
      permissions.each do |permission|
        if !permission.in?(ApiKey.permissions_list)
          errors.add(:permissions, "can't allow invalid permission '#{permission}'")
        end
      end
    end

    class_methods do
      def normalize_permissions(permissions)
        permissions.compact_blank
      end

      def permissions_list
        Rails.application.routes.routes.select do |route|
          route.defaults[:controller].present? && !route.internal
        end.map do |route|
          "#{route.defaults[:controller]}:#{route.defaults[:action]}"
        end.uniq.sort
      end
    end
  end
end
