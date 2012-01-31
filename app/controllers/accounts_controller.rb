class AccountsController < ApplicationController

  # GET /accounts/1/edit
  def edit
    prepare params[:id]
  end

  # PUT /accounts/1
  # PUT /accounts/1.xml
  def update
    prepare params[:id]

    respond_to do |format|
      if @account.update_attributes params[:account]
        format.html { redirect_to edit_account_path(@account, :rg_account_id_hash => params[:rg_account_id_hash]), :notice => t('activerecord.models.account').capitalize + t('successfully_updated') }
        format.xml  { head :ok }
      else
        format.html { render :action => "edit" }
        format.xml  { render :xml => @account.errors, :status => :unprocessable_entity }
      end
    end
  end

  def sync
    prepare params[:id]

    system("#{RAILS_ROOT}/script/sync_one.sh " + @account.rg_account_id.to_s)

    respond_to do |format|
        format.html { render :action => "edit" }
        format.xml  { render :xml => @account.errors, :status => :unprocessable_entity }
     
    end
  end

  private
    def prepare(account_id)
      @account = Account.find account_id
      @mails_for_select = ApiOperations::Common.mails_for_select @account.rg_account_id
      @user_maps = UserMap.find_all_by_account_id account_id
      @new_user_map = UserMap.new
      @new_user_map.account = @account
    end

end
