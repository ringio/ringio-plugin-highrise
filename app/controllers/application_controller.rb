class ApplicationController < ActionController::Base
  protect_from_forgery

  before_filter :check_hash
  
  private
    # as this is a before_filter, the corresponding action will not run if here there is a render or redirect
    def check_hash

      if params[:rg_account_id_hash].present?

        # RESTful controller, resource is a child resource of account
        if params[:account_id].present?
          account = Account.find_by_id params[:account_id]
          check_hash_forbidden(params[:rg_account_id_hash],account)

        # RESTful controller, resource is an account
        elsif params[:id].present?
          account = Account.find_by_id params[:id]
          check_hash_forbidden(params[:rg_account_id_hash],account)

        # not RESTful controller
        elsif (params[:controller] == 'not_rest')
          account = Account.find_by_rg_account_id_hash params[:rg_account_id_hash]
          check_hash_forbidden(params[:rg_account_id_hash],account)

        else
          hash_problem :bad_request      
        end

      else
        hash_problem :bad_request
      end
    end

    
    def check_hash_forbidden(rg_account_id_hash,account)
      unless account && (rg_account_id_hash.to_s == ApiOperations::Hashing.digest(account.rg_account_id.to_s + RingioAPI::Base.user.to_s))
        hash_problem :forbidden
      end
    end

  
    def hash_problem(cause)
      respond_to do |format|
        format.html { head cause }
        format.xml  { head cause }
      end
    end
  
end
