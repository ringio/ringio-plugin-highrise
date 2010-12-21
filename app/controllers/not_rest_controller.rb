class NotRestController < ApplicationController

  skip_before_filter :check_hash, :only => [:create_account]

  # GET /not_rest/create_account?rg_account_id={Ringio not encrypted account id}
  def create_account
    @account = Account.new(:rg_account_id => params[:rg_account_id])

    respond_to do |format|
      if @account.save
        format.html { head :ok }
        format.xml  { head :ok }
      else
        format.xml  { render :xml => @account.errors, :status => :unprocessable_entity }
      end
    end
  end
  
  # GET /not_rest/edit_account?rg_account_id_hash={Ringio account id hash}
  def edit_account
    account = Account.find_by_rg_account_id_hash params[:rg_account_id_hash]
    account_id = account.nil? ? nil : account.id
    
    redirect_to :controller => 'accounts', :action => 'edit', :id => account_id, :rg_account_id_hash => params[:rg_account_id_hash]
  end
  
  # GET /not_rest/destroy_account?rg_account_id_hash={Ringio account id hash}
  def destroy_account
    @account = Account.find_by_rg_account_id_hash params[:rg_account_id_hash]
    @account.destroy

    respond_to do |format|
      format.html { head :ok }
      format.xml  { head :ok }
    end
  end

end
