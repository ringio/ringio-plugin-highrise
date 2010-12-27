class UserMapsController < ApplicationController

  # POST /user_maps
  # POST /user_maps.xml
  def create
    @new_user_map = UserMap.new params[:user_map]
    @account = Account.find params[:account_id]
    @new_user_map.account = @account
    @mails_for_select = ApiOperations::Common.mails_for_select @account.rg_account_id

    respond_to do |format|
      if @new_user_map.save
        if request.xhr?
          @new_user_map = UserMap.new
          @new_user_map.account = @account
          @user_maps = UserMap.find_all_by_account_id @account.id
          format.html { render :partial => "block_for_ajax" }        
        else
          format.html { head :created }
          format.xml  { render :xml => @new_user_map, :status => :created, :location => @new_user_map }
        end
      else
        if request.xhr?
          @user_maps = UserMap.find_all_by_account_id @account.id
          format.html { render :partial => "block_for_ajax" }
        else
          format.html { head :unprocessable_entity }
          format.xml  { render :xml => @new_user_map.errors, :status => :unprocessable_entity }
        end
      end
    end
  end

  # PUT /user_maps/1
  # PUT /user_maps/1.xml
  def update
    prepare params[:id]

    respond_to do |format|
      if @user_map.update_attributes params[:user_map]
        if request.xhr?
          @user_maps = UserMap.find_all_by_account_id @account.id
          format.html { render :partial => "account_form", :locals => {:account => @account, :user_map => @user_map} }        
        else
          format.html { head :ok }
          format.xml  { head :ok }
        end
      else
        if request.xhr?
          @user_maps = UserMap.find_all_by_account_id @account.id
          format.html { render :partial => "account_form", :locals => {:account => @account, :user_map => @user_map} }        
        else
          format.html { head :unprocessable_entity }
          format.xml  { render :xml => @user_map.errors, :status => :unprocessable_entity }
        end
      end
    end
  end

  # DELETE /user_maps/1
  # DELETE /user_maps/1.xml
  def destroy
    prepare params[:id]

    @user_map.destroy
    
    respond_to do |format|
      if request.xhr?
        @user_maps = UserMap.find_all_by_account_id @account.id
        format.html { render :partial => "block_for_ajax" }
      else
        format.html { head :ok }
        format.xml  { head :ok }
      end
    end
  end
  
  private
    def prepare(user_map_id)
      @user_map = UserMap.find user_map_id
      @account = @user_map.account
      @mails_for_select = ApiOperations::Common.mails_for_select @account.rg_account_id
      @new_user_map = UserMap.new
      @new_user_map.account = @account
    end

end

