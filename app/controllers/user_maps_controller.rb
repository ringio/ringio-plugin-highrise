class UserMapsController < ApplicationController

=begin
  # GET /user_maps
  # GET /user_maps.xml
  def index
    @user_maps = UserMap.all

    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => @user_maps }
    end
  end

  # GET /user_maps/1
  # GET /user_maps/1.xml
  def show
    @user_map = UserMap.find(params[:id])

    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render :xml => @user_map }
    end
  end

  # GET /user_maps/new
  # GET /user_maps/new.xml
  def new
    @user_map = UserMap.new

    respond_to do |format|
      format.html # new.html.erb
      format.xml  { render :xml => @user_map }
    end
  end

  # GET /user_maps/1/edit
  def edit
    @user_map = UserMap.find(params[:id])
  end
=end

  # POST /user_maps
  # POST /user_maps.xml
  def create
    @user_map = UserMap.new(params[:user_map])

    respond_to do |format|
      if @user_map.save
        if request.xhr?
          @user_maps = UserMap.all
          format.html { render :partial => "index" }        
        else
          format.html { redirect_to(@user_map, :notice => 'User map was successfully created.') }
          format.xml  { render :xml => @user_map, :status => :created, :location => @user_map }
        end
      else
        if request.xhr?
          @user_maps = UserMap.all
          format.html { render :partial => "index" }
        else
          format.html { render :action => "new" }
          format.xml  { render :xml => @user_map.errors, :status => :unprocessable_entity }
        end
      end
    end
  end

  # PUT /user_maps/1
  # PUT /user_maps/1.xml
  def update
    @user_map = UserMap.find(params[:id])

    respond_to do |format|
      if @user_map.update_attributes(params[:user_map])
        if request.xhr?
          @user_maps = UserMap.all
          format.html { render :partial => "index" }        
        else
          format.html { redirect_to(@user_map, :notice => 'User map was successfully updated.') }
          format.xml  { head :ok }
        end
      else
        if request.xhr?
          @user_maps = UserMap.all
          format.html { render :partial => "index" }        
        else
          format.html { render :action => "edit" }
          format.xml  { render :xml => @user_map.errors, :status => :unprocessable_entity }
        end
      end
    end
  end

  # DELETE /user_maps/1
  # DELETE /user_maps/1.xml
  def destroy
    @user_map = UserMap.find(params[:id])
    @user_map.destroy

    respond_to do |format|
      if request.xhr?
        @user_maps = UserMap.all
        format.html { render :partial => "index" }
      else
        format.html { redirect_to(user_maps_url) }
        format.xml  { head :ok }
      end
    end
  end
end
