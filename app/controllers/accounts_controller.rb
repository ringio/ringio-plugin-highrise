class AccountsController < ApplicationController

=begin
  # GET /accounts
  # GET /accounts.xml
  def index
    @accounts = Account.all

    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => @accounts }
    end
  end

  # GET /accounts/1
  # GET /accounts/1.xml
  def show
    @account = Account.find(params[:id])

    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render :xml => @account }
    end
  end


  # GET /accounts/new
  # GET /accounts/new.xml
  def new
    @account = Account.new

    respond_to do |format|
      format.html # new.html.erb
      format.xml  { render :xml => @account }
    end
  end

=end

  # GET /accounts/1/edit
  def edit
    prepare params[:id]
  end

=begin
  # POST /accounts
  # POST /accounts.xml
  def create
    @account = Account.new(:rg_account_id => params[:rg_account_id], :rg_account_token => params[:rg_account_token])

    respond_to do |format|
      if @account.save
        format.html { redirect_to(@account, :notice => 'Account was successfully created.') }
        format.xml  { render :xml => @account, :status => :created, :location => @account }
      else
        format.html { render :action => "new" }
        format.xml  { render :xml => @account.errors, :status => :unprocessable_entity }
      end
    end
  end
=end

  # PUT /accounts/1
  # PUT /accounts/1.xml
  def update
    prepare params[:id]

    respond_to do |format|
      if @account.update_attributes params[:account]
        format.html { redirect_to edit_account_path(@account), :notice => t('account.successfully_updated') }
        format.xml  { head :ok }
      else
        format.html { render :action => "edit" }
        format.xml  { render :xml => @account.errors, :status => :unprocessable_entity }
      end
    end
  end

=begin
  # DELETE /accounts/1
  # DELETE /accounts/1.xml
  def destroy
    @account = Account.find(params[:id])
    @account.destroy

    respond_to do |format|
      format.html { redirect_to(accounts_url) }
      format.xml  { head :ok }
    end
  end
=end

  private
    def prepare(account_id)
      @account = Account.find account_id
      @mails_for_select = ApiOperations.mails_for_select @account.rg_account_id
      @user_maps = UserMap.find_all_by_account_id account_id
      @new_user_map = UserMap.new
      @new_user_map.account = @account
    end

end
