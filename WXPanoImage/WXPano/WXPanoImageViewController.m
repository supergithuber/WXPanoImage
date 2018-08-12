//
//  WXPanoImageViewController.m
//  WXPanoImage
//
//  Created by 吴浠 on 2018/8/12.
//  Copyright © 2018年 吴浠. All rights reserved.
//

#import "WXPanoImageViewController.h"
#import <CoreMotion/CoreMotion.h>

#define FRAME_PER_SENCOND 60.0  //帧数
#define ES_PI  (3.14159265f)
#define MAX_VIEW_DEGREE 110.0f  //最大视角
#define MIN_VIEW_DEGREE 50.0f   //最小视角


@interface WXPanoImageViewController()<GLKViewDelegate, GLKViewControllerDelegate>

@property (nonatomic, strong) CMMotionManager *motionManager;//陀螺仪
@property (nonatomic, strong) GLKView         *panoramaView;//就是这个controller的view
//手势
@property (nonatomic, assign) CGFloat        scale; //两指缩放大小
@property (nonatomic, assign) BOOL           isTappedScale;//是否双击缩放
@property (nonatomic, assign) CGFloat        panX;
@property (nonatomic, assign) CGFloat        panY;
//openGL
@property (nonatomic, strong) GLKBaseEffect  *effect; //着色器
@property (nonatomic, assign) GLsizei        numIndices;//索引数
@property (nonatomic, assign) GLuint         vertexIndicesBuffer;// 顶点索引缓存指针
@property (nonatomic, assign) GLuint         vertexBuffer;// 顶点缓存指针
@property (nonatomic, assign) GLuint         vertexTexCoord;// 纹理缓存指针
@property (nonatomic, assign) GLKMatrix4     modelViewMatrix;// 模型坐标系


@end
@implementation WXPanoImageViewController

- (instancetype)initWithImageName:(NSString *)imageName type:(NSString *)imageType{
    if (self = [super init]){
        self.imageName = imageName;
        self.imageType = imageType;
        
        [self setupPanoramView];
    }
    return self;
}
- (void)setupPanoramView{
    if (!self.imageName) {
        NSAssert(self.imageName.length != 0, @"image name is nil,please check image name of PanoramView");
        return;
    }
    EAGLContext *context                  = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES3];
    self.panoramaView                     = (GLKView *)self.view;
    self.panoramaView.drawableColorFormat = GLKViewDrawableColorFormatRGBA8888;
    self.panoramaView.drawableDepthFormat = GLKViewDrawableDepthFormat24;
    self.panoramaView.context             = context;
    self.panoramaView.delegate            = self;
    [EAGLContext setCurrentContext:context];
    
    [self addGesture];
    
    [self startPanoramView];
}

- (void)addGesture{
    UIPanGestureRecognizer *pan =[[UIPanGestureRecognizer alloc] initWithTarget:self
                                                                         action:@selector(panGestture:)];
    
    UIPinchGestureRecognizer *pinch = [[UIPinchGestureRecognizer alloc] initWithTarget:self
                                                                                action:@selector(pinchGesture:)];
    
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self
                                                                          action:@selector(tapGesture:)];
    
    [self.view addGestureRecognizer:pan];
    [self.view addGestureRecognizer:pinch];
    [self.view addGestureRecognizer:tap];
    
    _scale = 1.0;
}
- (void)startPanoramView{
    self.delegate = self;
    self.preferredFramesPerSecond = FRAME_PER_SENCOND;//绘制频率
    
    [self setupOpenGL];
    [self startDeviceMotion];
}
- (void)stopPanoramView{
    
}
- (void)setupOpenGL{
    glEnable(GL_DEPTH_TEST);
    // 顶点
    GLfloat *vVertices  = NULL;
    // 纹理
    GLfloat *vTextCoord = NULL;
    // 索引
    GLuint *indices     = NULL;
    int numVertices     = 0;//三维顶点坐标数量
    
    _numIndices         = esGenSphere(200, 1.0, &vVertices, &vTextCoord, &indices, &numVertices);
    // 创建索引buffer并将indices的数据放入
    glGenBuffers(1, &_vertexIndicesBuffer);
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, _vertexIndicesBuffer);
    glBufferData(GL_ELEMENT_ARRAY_BUFFER, _numIndices*sizeof(GLuint), indices, GL_STATIC_DRAW);
    // 创建顶点buffer并将vVertices中的数据放入
    glGenBuffers(1, &_vertexBuffer);
    glBindBuffer(GL_ARRAY_BUFFER, _vertexBuffer);
    glBufferData(GL_ARRAY_BUFFER, numVertices*3*sizeof(GLfloat), vVertices, GL_STATIC_DRAW);
    //设置顶点属性,对顶点的位置，颜色，坐标进行赋值
    glEnableVertexAttribArray(GLKVertexAttribPosition);
    glVertexAttribPointer(GLKVertexAttribPosition, 3, GL_FLOAT, GL_FALSE, sizeof(GLfloat)*3, NULL);
    // 创建纹理buffer并将vTextCoord数据放入
    glGenBuffers(1, &_vertexTexCoord);
    glBindBuffer(GL_ARRAY_BUFFER, _vertexTexCoord);
    glBufferData(GL_ARRAY_BUFFER, numVertices*2*sizeof(GLfloat), vTextCoord, GL_DYNAMIC_DRAW);
    //设置纹理属性,对纹理的位置，颜色，坐标进行赋值
    glEnableVertexAttribArray(GLKVertexAttribTexCoord0);
    glVertexAttribPointer(GLKVertexAttribTexCoord0, 2, GL_FLOAT, GL_FALSE, sizeof(GLfloat)*2, NULL);
    
    NSString *filePath = [[NSBundle mainBundle]pathForResource:self.imageName ofType:self.imageType];
    NSDictionary *options = [NSDictionary dictionaryWithObjectsAndKeys:@(1),GLKTextureLoaderOriginBottomLeft, nil];
    GLKTextureInfo *textureInfo = [GLKTextureLoader textureWithContentsOfFile:filePath
                                                                      options:options
                                                                        error:nil];
    _effect                    = [[GLKBaseEffect alloc]init];
    _effect.texture2d0.enabled = GL_TRUE;
    _effect.texture2d0.name    = textureInfo.name;
}
- (void)startDeviceMotion{
    [self.motionManager startDeviceMotionUpdatesUsingReferenceFrame:CMAttitudeReferenceFrameXArbitraryCorrectedZVertical];
    _modelViewMatrix = GLKMatrix4Identity;
}

#pragma mark -GLKViewDelegate
- (void)glkView:(GLKView *)view drawInRect:(CGRect)rect{
    //白色
    glClearColor(1.0f, 1.0f, 1.0f, 0.0f);
    glClear(GL_COLOR_BUFFER_BIT|GL_DEPTH_BUFFER_BIT);//清除缓冲区
    [_effect prepareToDraw];
    glDrawElements(GL_TRIANGLES, _numIndices, GL_UNSIGNED_INT,0);

}
#pragma mark -GLKViewControllerDelegate
- (void)glkViewControllerUpdate:(GLKViewController *)controller {
    CGSize size    = self.view.bounds.size;
    float aspect   = fabs(size.width / size.height);
    
    CGFloat radius = [self rotateFromFocalLengh];
    
    /**GLKMatrix4MakePerspective 配置透视图
     第一个参数, 类似于相机的焦距, 比如10表示窄角度, 100表示广角 一般65-75;
     第二个参数: 表示时屏幕的纵横比
     第三个, 第四参数: 是为了实现透视效果, 近大远处小, 要确保模型位于远近平面之间
     */
    GLKMatrix4 projectionMatrix        = GLKMatrix4MakePerspective(GLKMathDegreesToRadians(radius),
                                                                   aspect,
                                                                   0.1f,
                                                                   1);
    
    GLKQuaternion quaternion;
    
    projectionMatrix                   = GLKMatrix4Scale(projectionMatrix, -1.0f, 1.0f, 1.0f);
    
    CMDeviceMotion *deviceMotion       = self.motionManager.deviceMotion;
    
    double w                           = deviceMotion.attitude.quaternion.w;
    double wx                          = deviceMotion.attitude.quaternion.x;
    double wy                          = deviceMotion.attitude.quaternion.y;
    double wz                          = deviceMotion.attitude.quaternion.z;
    
    quaternion = GLKQuaternionMake(-wx,  wy, wz, w);
    NSLog(@"%f,%f,%f,%f",wx,wy,wz,w);
    
    GLKMatrix4 rotation                = GLKMatrix4MakeWithQuaternion(quaternion);
    
    //上下滑动，绕X轴旋转
    projectionMatrix                   = GLKMatrix4RotateX(projectionMatrix, -0.005 * _panY);
    projectionMatrix                   = GLKMatrix4Multiply(projectionMatrix, rotation);
    // 为了保证在水平放置手机的时候, 是从下往上看, 因此首先坐标系沿着x轴旋转90度
    projectionMatrix                   = GLKMatrix4RotateX(projectionMatrix, M_PI_2);
    
    _effect.transform.projectionMatrix = projectionMatrix;
    GLKMatrix4 modelViewMatrix         = GLKMatrix4Identity;
    //左右滑动绕Y轴旋转
    modelViewMatrix                    = GLKMatrix4RotateY(modelViewMatrix, 0.005 * _panX);
    _effect.transform.modelviewMatrix  = modelViewMatrix;
}
- (void)glkViewController:(GLKViewController *)controller willPause:(BOOL)pause{
    
}
- (CGFloat)rotateFromFocalLengh{
    
    CGFloat radius = 100 / _scale;
    
    // radius不小于50, 不大于110;
    if (radius < MIN_VIEW_DEGREE) {
        radius = MIN_VIEW_DEGREE;
        _scale = 1 / (MIN_VIEW_DEGREE / 100);
    }
    if (radius > MAX_VIEW_DEGREE) {
        radius = MAX_VIEW_DEGREE;
        _scale = 1 / (MAX_VIEW_DEGREE / 100);
    }
    return radius;
}
//手势方法
- (void)panGestture:(UIPanGestureRecognizer *)sender{
    CGPoint point = [sender translationInView:self.view];
    _panX += point.x;
    _panY += point.y;
    
    [sender setTranslation:CGPointZero inView:self.view];
}
- (void)pinchGesture:(UIPinchGestureRecognizer *)sender{
    _scale *= sender.scale;
    sender.scale = 1.0;
}
- (void)tapGesture:(UITapGestureRecognizer *)sender{
    if (!_isTappedScale) {
        _isTappedScale = YES;
        _scale = 1.5;
    }else{
        _scale = 1.0;
        _isTappedScale = NO;
    }
}
//MARK: set and get
- (NSString *)imageType{
    if (!_imageType){
        return @"jpg";
    }
    return _imageType;
}
- (CMMotionManager *)motionManager{
    if (_motionManager == nil) {
        _motionManager = [[CMMotionManager alloc] init];
        _motionManager.deviceMotionUpdateInterval = 1/FRAME_PER_SENCOND;
        _motionManager.showsDeviceMovementDisplay = YES;
    }
    return _motionManager;
}
//MARK: - util
/**
 根据numSlices和radius的大小取索引，顶点，纹理的值
 
 @param numSlices 球面切面数量
 @param radius 半径
 @param vertices 3维顶点坐标
 @param texCoords 纹理
 @param indices 索引
 @param vertices_count 3维顶点坐标数量
 @return 索引数量
 */
int esGenSphere(int numSlices,
                float radius,
                float **vertices,
                float **texCoords,
                uint32_t **indices,
                int *vertices_count) {
    
    
    int numParallels = numSlices / 2;
    int numVertices  = (numParallels + 1) * (numSlices + 1);
    int numIndices   = numParallels * numSlices * 6;
    
    float angleStep  = (2.0f * ES_PI) / ((float) numSlices);
    
    if (vertices != NULL) {
        *vertices = malloc(sizeof(float) * 3 * numVertices);
    }
    
    if (texCoords != NULL) {
        *texCoords = malloc(sizeof(float) * 2 * numVertices);
    }
    
    if (indices != NULL) {
        *indices = malloc(sizeof(uint32_t) * numIndices);
    }
    
    for (int i = 0; i < numParallels + 1; i++) {
        for (int j = 0; j < numSlices + 1; j++) {
            int vertex = (i * (numSlices + 1) + j) * 3;
            
            if (vertices) {
                (*vertices)[vertex + 0] = radius * sinf(angleStep * (float)i) * sinf(angleStep * (float)j);
                (*vertices)[vertex + 1] = radius * cosf(angleStep * (float)i);
                (*vertices)[vertex + 2] = radius * sinf(angleStep * (float)i) * cosf(angleStep * (float)j);
            }
            
            if (texCoords) {
                int texIndex = (i * (numSlices + 1) + j) * 2;
                (*texCoords)[texIndex + 0] = (float)j / (float)numSlices;
                (*texCoords)[texIndex + 1] = 1.0f - ((float)i / (float)numParallels);
            }
        }
    }
    
    // Generate the indices
    if (indices != NULL) {
        uint32_t *indexBuf = (*indices);
        for (int i = 0; i < numParallels ; i++) {
            for (int j = 0; j < numSlices; j++) {
                *indexBuf++ = i * (numSlices + 1) + j;
                *indexBuf++ = (i + 1) * (numSlices + 1) + j;
                *indexBuf++ = (i + 1) * (numSlices + 1) + (j + 1);
                
                *indexBuf++ = i * (numSlices + 1) + j;
                *indexBuf++ = (i + 1) * (numSlices + 1) + (j + 1);
                *indexBuf++ = i * (numSlices + 1) + (j + 1);
            }
        }
    }
    
    if (vertices_count) {
        *vertices_count = numVertices;
    }
    
    return numIndices;
}
@end
