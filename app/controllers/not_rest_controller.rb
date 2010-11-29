class NotRestController < ApplicationController
  
  # GET /not_rest/create_account?rg_account_id={Ringio Account Id}
  def create_account
    @account = Account.new(:rg_account_id => params[:rg_account_id])

    respond_to do |format|
      if @account.save
        format.html { head :ok } # redirect_to(@account, :notice => 'Account was successfully created.') }
        format.xml  { head :ok } # render :xml => @account, :status => :created, :location => @account }
      else
        # format.html { render :action => "new" }
        format.xml  { render :xml => @account.errors, :status => :unprocessable_entity }
      end
    end
  end
  
  # GET /not_rest/edit_account?rg_account_id={Ringio Account Id}
  def edit_account
    account = Account.find_by_rg_account_id params[:rg_account_id]
    account_id = account.nil? ? nil : account.id
    
    redirect_to :controller => 'accounts', :action => 'edit', :id => account_id
  end
  
  # GET /not_rest/destroy_account?rg_account_id={Ringio Account Id}
  def destroy_account
    @account = Account.find_by_rg_account_id params[:rg_account_id]
    @account.destroy

    respond_to do |format|
      format.html { head :ok } # redirect_to(accounts_url) }
      format.xml  { head :ok }
    end
  end
  
end
