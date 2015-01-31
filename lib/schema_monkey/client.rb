module SchemaMonkey
  class Client
    def initialize(mod)
      @root = mod
      @inserted = {}
    end

    def insert(opts={})
      opts = opts.keyword_args(:dbm)
      include_modules(dbm: opts.dbm)
      insert_middleware(dbm: opts.dbm)
      @root.insert() if @root.respond_to?(:insert) and @root != ::SchemaMonkey
    end

    def include_modules(opts={})
      opts = opts.keyword_args(:dbm)
      find_modules(:ActiveRecord, dbm: opts.dbm).each do |mod|
        next if mod.is_a? Class
        component = mod.to_s.sub(/^#{@root}::ActiveRecord::/, '')
        component = component.gsub(/#{opts.dbm}/i, opts.dbm.to_s) if opts.dbm # canonicalize case
        next unless base = Module.get_const(::ActiveRecord, component)
        # Kernel.warn "including #{mod}"
        Module.include_once base, mod
      end
    end

    def insert_middleware(opts={})
      opts = opts.keyword_args(:dbm)
      find_modules(:Middleware, dbm: opts.dbm, and_self: true).each do |mod|
        next if @inserted[mod]
        next unless mod.respond_to? :insert
        # Kernel.warn "inserting #{mod}"
        mod.insert
        @inserted[mod] = true
      end
    end

    private

    def find_modules(container, opts={})
      opts = opts.keyword_args(dbm: nil, and_self: nil)
      return [] unless (container = Module.get_const(@root, container))

      if opts.dbm
        accept = /\b#{opts.dbm}/i
        reject = nil
      else
        accept = nil
        reject = /\b#{SchemaMonkey::DBMS.join('|')}/i
      end

      modules = []
      modules << container if opts.and_self
      modules += Module.descendants(container, can_load: accept)
      modules.select!(&it.to_s =~ accept) if accept
      modules.reject!(&it.to_s =~ reject) if reject
      modules
    end

  end
end